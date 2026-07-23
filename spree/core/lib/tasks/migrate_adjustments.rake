namespace :spree do
  desc <<~DESC
    Backfills typed adjustment lines (TaxLine, DiscountLine, Fee) from frozen
    spree_adjustments rows for completed orders. Runs once at upgrade time,
    after the 6.0 code is deployed. Idempotent: orders that already have any
    typed rows are skipped. Incomplete orders are skipped entirely — their
    first recalculation rewrites typed rows from source.

    Mapping per adjustment row:
      * Spree::TaxRate source          → TaxLine (zero amounts skipped; rows whose
        rate no longer exists, and order-level tax rows — which no supported
        upgrade path produces — are skipped loudly)
      * Spree::PromotionAction source  → DiscountLine, only eligible rows with
        amount < 0 (drops best-promo losers and $0 FreeShipping placeholders)
      * no source (manual)             → sign split: amount < 0 → DiscountLine
        (kind 'manual'), amount > 0 → Fee (kind 'manual'), zero skipped
      * Spree::ReturnAuthorization     → skipped (vestigial; returns flow through Refund)
      * anything else                  → sign split like manual, kind 'legacy'
        (Fee validates amount >= 0, so negative rows must be DiscountLines)

    Order-level (adjustable_type Spree::Order) discount and fee amounts are
    distributed across line items with the same largest-remainder function
    runtime uses (Spree::Adjustments::DistributeAmount), so migrated rows sum
    exactly to the frozen amount and place pennies exactly where a 6.0-born
    order would.

    pre_tax_amount is never rewritten: completed orders keep the values
    written under the semantics in force at completion.

    Each order migrates in a transaction — on error the order is left
    untouched (and still eligible for a re-run), logged, and counted.
  DESC
  task migrate_adjustments: :environment do
    migrated = skipped_existing = failed = 0
    skipped_rows = Hash.new(0)

    # line_item_id / fulfillment_id attributes for a directly-attached adjustment
    adjustable_attributes = lambda do |adjustment|
      case adjustment.adjustable_type
      when 'Spree::LineItem' then { line_item_id: adjustment.adjustable_id }
      when 'Spree::Shipment' then { fulfillment_id: adjustment.adjustable_id }
      else
        raise "unsupported adjustable_type #{adjustment.adjustable_type} on adjustment #{adjustment.id}"
      end
    end

    # Order-level amounts become per-line rows via the runtime splitting function.
    distribute_to_line_items = lambda do |adjustment, line_items, attributes|
      shares = Spree::Adjustments::DistributeAmount.new(amount: adjustment.amount, line_items: line_items).call
      if shares.empty?
        Rails.logger.warn("[migrate_adjustments] order-level adjustment #{adjustment.id} not distributable (no line items or zero item total), skipping")
        skipped_rows[:not_distributable] += 1
        next
      end

      model = adjustment.amount.negative? ? Spree::DiscountLine : Spree::Fee
      shares.each do |line_item_id, share|
        next if share.zero?

        model.create!(amount: share, line_item_id: line_item_id, **attributes)
      end
    end

    # Manual and unknown-source rows: credits become DiscountLines, charges
    # become Fees — mandated by the amount validations (Resolved Question 7).
    migrate_sign_split = lambda do |adjustment, line_items, kind|
      next skipped_rows[:zero_amount] += 1 if adjustment.amount.zero?

      attributes = { order_id: adjustment.order_id, label: adjustment.label, kind: kind }

      if adjustment.adjustable_type == 'Spree::Order'
        distribute_to_line_items.call(adjustment, line_items, attributes)
      else
        model = adjustment.amount.negative? ? Spree::DiscountLine : Spree::Fee
        model.create!(amount: adjustment.amount, **attributes, **adjustable_attributes.call(adjustment))
      end
    end

    candidates = Spree::Order.where.not(completed_at: nil).
                 where(id: Spree::Adjustment.select(:order_id))

    candidates.find_each do |order|
      if Spree::TaxLine.where(order_id: order.id).exists? ||
          Spree::DiscountLine.where(order_id: order.id).exists? ||
          Spree::Fee.where(order_id: order.id).exists?
        skipped_existing += 1
        next
      end

      line_items = order.line_items.to_a

      ActiveRecord::Base.transaction do
        Spree::Adjustment.where(order_id: order.id).find_each do |adjustment|
          case adjustment.source_type
          when 'Spree::TaxRate'
            unless Spree::TaxRate.with_deleted.exists?(adjustment.source_id)
              Rails.logger.warn("[migrate_adjustments] order #{order.number}: tax adjustment #{adjustment.id} references missing tax rate #{adjustment.source_id}, skipping")
              skipped_rows[:tax_rate_missing] += 1
              next
            end
            if adjustment.adjustable_type == 'Spree::Order'
              Rails.logger.warn("[migrate_adjustments] order #{order.number}: order-level tax adjustment #{adjustment.id}, skipping")
              skipped_rows[:order_level_tax] += 1
              next
            end
            next skipped_rows[:zero_amount] += 1 if adjustment.amount.zero?

            Spree::TaxLine.create!(
              order_id: order.id,
              tax_rate_id: adjustment.source_id,
              amount: adjustment.amount,
              label: adjustment.label,
              included: adjustment.included,
              **adjustable_attributes.call(adjustment)
            )
          when 'Spree::PromotionAction'
            next skipped_rows[:promo_loser_or_placeholder] += 1 unless adjustment.eligible? && adjustment.amount.negative?

            action = Spree::PromotionAction.with_deleted.find_by(id: adjustment.source_id)
            attributes = {
              order_id: order.id,
              promotion_action_id: adjustment.source_id,
              promotion_id: action&.promotion_id,
              label: adjustment.label
            }

            if adjustment.adjustable_type == 'Spree::Order'
              distribute_to_line_items.call(adjustment, line_items, attributes)
            else
              Spree::DiscountLine.create!(amount: adjustment.amount, **attributes, **adjustable_attributes.call(adjustment))
            end
          when nil
            migrate_sign_split.call(adjustment, line_items, 'manual')
          when 'Spree::ReturnAuthorization'
            skipped_rows[:return_authorization] += 1
          else
            migrate_sign_split.call(adjustment, line_items, 'legacy')
          end
        end
      end

      migrated += 1
    rescue StandardError => e
      failed += 1
      Rails.logger.error("[migrate_adjustments] order #{order.number}: #{e.class}: #{e.message}")
    end

    puts "  Migrated #{migrated} order(s), skipped #{skipped_existing} already-migrated, #{failed} failed (see log)."
    puts "  Skipped rows: #{skipped_rows.inspect}" if skipped_rows.any?
  end
end
