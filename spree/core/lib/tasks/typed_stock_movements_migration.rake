# frozen_string_literal: true

# Defined here rather than in lib/spree/core/ — this is a one-release upgrade
# step that dies with the polymorphic originator in 6.1, not engine
# infrastructure. Same placement as Spree::ReturnsMigrator in a sibling task.
module Spree
  # Types the legacy stock-movement history and reconciles open fulfillments
  # onto the allocation model (docs/plans/6.0-typed-stock-movements.md).
  #
  # Two jobs in one idempotent task. Typing narrows to rows without a kind;
  # reconciliation skips fulfillments that already hold an allocation. Both
  # predicates are queries over the data itself, so an interrupted run resumes
  # for free and a second run finds nothing to do. That same predicate is what
  # makes the deploy window safe: a fulfillment shipped before the task runs
  # never gets an allocation, and dispatch only ships allocated units.
  #
  # Runs after spree:migrate_shipping_to_delivery, which rewrites the
  # 'Spree::Shipment' originator strings, and after
  # spree:upgrade:migrate_returns, because a legacy authorization id says
  # nothing about the new record — the returns migrator preserves the number,
  # not the id, and one authorization can become either a Return or an
  # Exchange.
  class TypedStockMovementsMigration
    LEGACY_ADJUSTMENT_REASON = 'Legacy manual adjustment'
    LEGACY_RETURN_TABLE = 'spree_return_authorizations'
    FULFILLMENT_ORIGINATOR_TYPES = ['Spree::Fulfillment', 'Spree::Shipment'].freeze

    def initialize(batch_size: 5_000)
      @batch_size = batch_size
      @typed = 0
      @reconciled = 0
    end

    # @return [Hash] counts of rows typed and fulfillments reconciled
    def call
      type_history
      reconcile_open_fulfillments

      { typed: @typed, reconciled: @reconciled }
    end

    private

    attr_reader :batch_size

    def type_history
      Spree::StockMovement.unscoped.where(kind: nil).find_each(batch_size: batch_size) do |movement|
        attributes = attributes_for(movement)
        Spree::StockMovement.unscoped.where(id: movement.id).update_all(attributes.merge(updated_at: Time.current))
        @typed += 1
      end
    end

    def attributes_for(movement)
      return { kind: 'adjusted', reason: LEGACY_ADJUSTMENT_REASON } if movement.originator_type.blank?

      case movement.originator_type
      when *FULFILLMENT_ORIGINATOR_TYPES then fulfillment_attributes(movement)
      when 'Spree::StockTransfer' then stock_transfer_attributes(movement)
      when 'Spree::ReturnAuthorization' then return_attributes(movement)
      else by_sign(movement)
      end
    end

    # A departure, or the restock of a cancellation or relocation, carrying
    # the order the fulfillment belonged to so "which order was this for?"
    # costs no join.
    def fulfillment_attributes(movement)
      fulfillment = Spree::Fulfillment.find_by(id: movement.originator_id)
      return by_sign(movement) if fulfillment.nil?

      by_sign(movement, negative: 'shipped', positive: 'released').
        merge(fulfillment_id: fulfillment.id, order_id: fulfillment.order_id)
    end

    def stock_transfer_attributes(movement)
      return by_sign(movement) unless Spree::StockTransfer.exists?(id: movement.originator_id)

      by_sign(movement).merge(stock_transfer_id: movement.originator_id)
    end

    # The legacy id is worthless on its own, so the authorization is read by
    # name and its preserved number matched against whichever record the
    # returns migrator produced.
    def return_attributes(movement)
      attributes = { kind: 'received', quantity: movement.quantity.to_i.abs }
      record = migrated_return_for(movement.originator_id)

      case record
      when Spree::Return then attributes.merge(return_id: record.id, order_id: record.order_id)
      when Spree::Exchange then attributes.merge(exchange_id: record.id, order_id: record.order_id)
      else attributes
      end
    end

    def migrated_return_for(authorization_id)
      return nil unless legacy_returns

      number = legacy_returns.where(id: authorization_id).pick(:number)
      return nil if number.blank?

      Spree::Return.find_by(number: number) || Spree::Exchange.find_by(number: number)
    end

    def legacy_returns
      return @legacy_returns if defined?(@legacy_returns)

      @legacy_returns =
        if ActiveRecord::Base.connection.table_exists?(LEGACY_RETURN_TABLE)
          Class.new(Spree.base_class) do
            self.table_name = LEGACY_RETURN_TABLE
            def self.name = 'LegacyReturnAuthorization'
          end
        end
    end

    # A movement whose cause cannot be resolved is still a true statement
    # about stock, so it is typed by which way the stock went and left with no
    # cause key rather than skipped. The three order-driven kinds are written
    # positive — the kind carries the direction now.
    def by_sign(movement, negative: 'shipped', positive: 'received')
      quantity = movement.quantity.to_i

      { kind: quantity.negative? ? negative : positive, quantity: quantity.abs }
    end

    # Under the old model an unfulfilled fulfillment on a placed order had
    # already taken its units off the shelf. Under the new one those units are
    # on the shelf and allocated, so both counters move together and
    # availability is unchanged by construction — backordered units included,
    # since the pair of increments cancels out the negative on-hand that used
    # to represent them.
    def reconcile_open_fulfillments
      open_fulfillments.find_each(batch_size: batch_size) do |fulfillment|
        next if fulfillment.stock_location.nil?
        next if Spree::StockMovement.exists?(fulfillment_id: fulfillment.id, kind: 'allocated')

        reconcile(fulfillment)
      end
    end

    def open_fulfillments
      Spree::Fulfillment.
        where(status: 'unfulfilled').
        joins(:order).
        where.not(Spree::Order.table_name => { completed_at: nil })
    end

    def reconcile(fulfillment)
      quantities = fulfillment.fulfillment_items.group(:variant_id).sum(:quantity)
      return if quantities.empty?

      ActiveRecord::Base.transaction do
        quantities.each do |variant_id, quantity|
          quantity = quantity.to_i
          next unless quantity.positive?

          variant = Spree::Variant.with_deleted.find_by(id: variant_id)
          next if variant.nil? || !variant.should_track_inventory?

          stock_level = fulfillment.stock_location.stock_level_or_create(variant)
          # A direct column write, not a `received` movement: no goods
          # arrived. The allocation below is what gives the jump a cause.
          stock_level.update_columns(count_on_hand: stock_level.count_on_hand + quantity, updated_at: Time.current)
          fulfillment.stock_location.allocate(variant, quantity, fulfillment)
        end
      end

      @reconciled += 1
    end
  end
end

namespace :spree do
  desc <<~DESC
    Type legacy stock movements and reconcile open fulfillments onto allocations.

    Gives every pre-6.0 movement a kind and a concrete cause key derived from
    its polymorphic originator, then puts the units of every open fulfillment
    on a placed order back on the shelf and allocates them, which is where
    they belong now that stock leaves at dispatch rather than at placement.

    Run after spree:migrate_shipping_to_delivery and after
    spree:upgrade:migrate_returns. Idempotent. Tune the load size with
    BATCH_SIZE (default 5000).
  DESC
  task migrate_stock_movements_to_typed_rows: :environment do
    result = Spree::TypedStockMovementsMigration.new(batch_size: ENV.fetch('BATCH_SIZE', 5_000).to_i).call

    puts "spree_stock_movements: #{result[:typed]} legacy rows typed"
    puts "spree_fulfillments: #{result[:reconciled]} open fulfillments reconciled onto allocations"
    puts 'migrate_stock_movements_to_typed_rows done.'
  end
end
