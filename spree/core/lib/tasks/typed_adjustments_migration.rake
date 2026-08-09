# frozen_string_literal: true

# 5.6 → 6.0: convert legacy polymorphic spree_adjustments rows into the typed
# TaxLine / Discount / Fee tables (docs/plans/6.0-6.1-split-adjustments.md, Wave 7).
#
# Contract:
#   - Legacy rows are READ ONLY — spree_adjustments stays in place through 6.0
#     and remains the rollback source.
#   - Order totals are never touched; a per-order reconciliation asserts the
#     typed sums match the order's stored totals. Orders that do not reconcile
#     are logged and marked recalculation-frozen (metadata flag), never
#     force-balanced.
#   - Idempotent: orders with any typed rows already present are skipped.
namespace :spree do
  desc 'Convert legacy spree_adjustments into typed TaxLine/Discount/Fee rows'
  task migrate_adjustments_to_typed_rows: :environment do
    legacy = Class.new(ActiveRecord::Base) { self.table_name = 'spree_adjustments' }
    abort 'spree_adjustments table not found — nothing to migrate' unless legacy.table_exists?

    batch_size = ENV.fetch('BATCH_SIZE', 500).to_i
    stats = Hash.new(0)

    order_ids = legacy.distinct.pluck(:order_id)
    puts "#{order_ids.size} orders carry legacy adjustments"

    order_ids.each_slice(batch_size) do |slice|
      Spree::Order.unscoped.where(id: slice).includes(:line_items).each do |order|
        if Spree::TaxLine.where(order_id: order.id).exists? ||
            Spree::Discount.where(order_id: order.id).exists? ||
            Spree::Fee.where(order_id: order.id).exists?
          stats[:skipped_already_typed] += 1
          next
        end

        rows = legacy.where(order_id: order.id).to_a
        frozen_reason = nil

        ActiveRecord::Base.transaction do
          rows.each do |row|
            adjustable = Spree::TypedAdjustmentsMigration.resolve_typed_adjustable(order, row)

            case row.source_type
            when 'Spree::TaxRate'
              next unless row.eligible

              tax_rate = Spree::TaxRate.with_deleted.find_by(id: row.source_id)
              Spree::TaxLine.create!(
                order_id: order.id,
                line_item: adjustable[:line_item],
                fulfillment: adjustable[:fulfillment],
                tax_rate_id: tax_rate&.id,
                amount: row.amount,
                rate: tax_rate&.amount || 0,
                label: row.label.to_s.presence || 'Tax',
                included: row.included,
                provider_id: 'internal'
              )
              stats[:tax_lines] += 1
            when 'Spree::PromotionAction'
              next unless row.eligible

              action = Spree::PromotionAction.with_deleted.find_by(id: row.source_id)
              promotion = action&.promotion
              Spree::TypedAdjustmentsMigration.build_distributed_discounts(order, row, adjustable, promotion, action, stats)
            when nil
              if row.amount.to_f.negative?
                Spree::TypedAdjustmentsMigration.build_distributed_discounts(order, row, adjustable, nil, nil, stats, kind: 'manual')
              else
                Spree::Fee.create!(
                  order_id: order.id,
                  line_item: adjustable[:line_item],
                  fulfillment: adjustable[:fulfillment],
                  amount: row.amount,
                  label: row.label.to_s.presence || 'Fee',
                  kind: 'surcharge'
                )
                stats[:fees] += 1
              end
            when 'Spree::ReturnAuthorization'
              frozen_reason = 'return_authorization_adjustment'
              stats[:skipped_return_authorization] += 1
            else
              Spree::Fee.create!(
                order_id: order.id,
                line_item: adjustable[:line_item],
                fulfillment: adjustable[:fulfillment],
                amount: [row.amount, 0].max,
                label: row.label.to_s.presence || row.source_type,
                kind: 'surcharge',
                metadata: { 'legacy_source_type' => row.source_type, 'legacy_source_id' => row.source_id }
              )
              stats[:fees_unknown_source] += 1
            end
          end

          # Reconciliation: typed sums must match the stored order totals the
          # customer was charged. discount_total compares against promotion rows;
          # tax against tax lines.
          unless frozen_reason
            promo_delta = (Spree::Discount.where(order_id: order.id, kind: 'promotion').sum(:amount) - order.discount_total.to_d).abs
            tax_delta = (Spree::TaxLine.where(order_id: order.id, included: false).sum(:amount) - order.additional_tax_total.to_d).abs
            frozen_reason = 'totals_do_not_reconcile' if promo_delta > 0.01 || tax_delta > 0.01
          end

          if frozen_reason
            order.update_columns(
              metadata: (order.metadata || {}).merge(
                'typed_adjustments_frozen' => frozen_reason,
                'typed_adjustments_frozen_at' => Time.current.iso8601
              )
            )
            stats[:frozen_orders] += 1
            puts "FROZEN order #{order.number}: #{frozen_reason}"
          end
        end
      rescue StandardError => e
        stats[:errored_orders] += 1
        puts "ERROR order #{order.number}: #{e.class} #{e.message}"
      end
      print '.'
    end

    puts
    stats.each { |key, value| puts "#{key}: #{value}" }
    puts 'migrate_adjustments_to_typed_rows done. spree_adjustments left intact for rollback.'
  end
end

module Spree
  module TypedAdjustmentsMigration
    module_function

    # Resolves the legacy adjustable into the typed target hash. Order-level
    # rows return an empty target — the caller distributes them across line items.
    def resolve_typed_adjustable(order, row)
      case row.adjustable_type
      when 'Spree::LineItem'
        line_item = order.line_items.detect { |item| item.id == row.adjustable_id }
        { line_item: line_item }
      when 'Spree::Fulfillment', 'Spree::Shipment'
        { fulfillment: Spree::Fulfillment.unscoped.find_by(id: row.adjustable_id) }
      else
        {}
      end
    end

    # Line/fulfillment-targeted discounts become one row; order-level amounts
    # are distributed across line items largest-remainder over their amounts,
    # matching the runtime adjuster so migrated and fresh data split identically.
    def build_distributed_discounts(order, row, adjustable, promotion, action, stats, kind: 'promotion')
      base_attributes = {
        order_id: order.id,
        label: row.label.to_s.presence || promotion&.name || 'Discount',
        kind: kind,
        code: promotion&.code.presence,
        promotion_id: promotion&.id,
        promotion_action_id: action&.id
      }

      if adjustable[:line_item] || adjustable[:fulfillment]
        Spree::Discount.create!(
          base_attributes.merge(
            line_item: adjustable[:line_item],
            fulfillment: adjustable[:fulfillment],
            amount: [row.amount, 0].min
          )
        )
        stats[:discounts] += 1
        return
      end

      line_items = order.line_items.to_a
      bases = line_items.map { |item| [item.amount.to_d, BigDecimal(0)].max }
      bases_sum = bases.sum
      return if bases_sum <= 0

      total_cents = ([row.amount.to_d.abs, bases_sum].min * 100).round
      shares = Spree::Adjusters::LargestRemainder.largest_remainder_shares(total_cents, bases)

      line_items.each_with_index do |item, index|
        amount = -BigDecimal(shares[index]) / 100
        next if amount.zero?

        Spree::Discount.create!(base_attributes.merge(line_item: item, amount: amount))
        stats[:discounts_distributed] += 1
      end
    end
  end
end
