module Spree
  module StockLevels
    # Recomputes `reserved_count` and `incoming_count` on every stock level
    # from their sources — the reservation rows on the level, and the awaited
    # units on open purchase orders and in-flight transfers bound for the
    # level's location — and rewrites any row whose stored figure differs.
    #
    # The writers keep the counters right; this is the repair for when one of
    # them did not, and the backfill for installs that predate the columns.
    # Idempotent, and safe on a live store: each level is measured and
    # written under the same lock every writer takes.
    class Recount
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the list of corrected
      #   rows: `{ stock_level:, reserved: [was, now], incoming: [was, now] }`
      def call
        sweep_expired_reservations
        success(candidate_levels.filter_map { |stock_level| correct(stock_level) })
      end

      private

      # Expired holds are removed before anything is measured, so the two
      # definitions of reserved — the rows that exist, which is what the
      # writers keep, and the holds still active, which is what a reader
      # means — are the same thing. Assuming the sweep job has already run
      # would make the task unsafe to run at any time.
      def sweep_expired_reservations
        Spree::StockReservation.sweep_expired
      end

      # Measured and written under the level's lock: a checkout or a receipt
      # landing while the task runs writes under the same lock, so its change
      # is counted rather than overwritten.
      def correct(stock_level)
        stock_level.with_lock do
          expected = { reserved_count: reserved_for(stock_level), incoming_count: incoming_for(stock_level) }
          next if expected == stock_level.slice(:reserved_count, :incoming_count).symbolize_keys

          correction = {
            stock_level: stock_level,
            reserved: [stock_level.reserved_count, expected[:reserved_count]],
            incoming: [stock_level.incoming_count, expected[:incoming_count]]
          }
          stock_level.update_columns(expected)
          correction
        end
      end

      def reserved_for(stock_level)
        stock_level.stock_reservations.sum(:quantity)
      end

      # Summed in Ruby so the recount shares `ReceivableItem#incoming` with the
      # writers rather than restating it in SQL.
      def incoming_for(stock_level)
        lines = incoming_purchase_order_lines.where(variant_id: stock_level.variant_id,
                                                    Spree::PurchaseOrder.table_name => { destination_location_id: stock_level.stock_location_id }) +
                incoming_transfer_lines.where(variant_id: stock_level.variant_id,
                                              Spree::StockTransfer.table_name => { destination_location_id: stock_level.stock_location_id })
        lines.sum(&:incoming)
      end

      def incoming_purchase_order_lines
        Spree::PurchaseOrderItem.joins(:purchase_order).merge(Spree::PurchaseOrder.incoming)
      end

      def incoming_transfer_lines
        Spree::StockTransferItem.joins(:stock_transfer).merge(Spree::StockTransfer.incoming)
      end

      # Every level that holds a figure or a reservation, plus every level a
      # document is bound for — created where the warehouse has never held
      # the SKU, as the writers would have.
      def candidate_levels
        levels = Spree::StockLevel.where.not(reserved_count: 0)
                                  .or(Spree::StockLevel.where.not(incoming_count: 0))
                                  .or(Spree::StockLevel.where(id: Spree::StockReservation.select(:stock_level_id)))
                                  .index_by { |level| [level.variant_id, level.stock_location_id] }

        missing = awaited_pairs.reject { |pair| levels.key?(pair) }
        locations = Spree::StockLocation.where(id: missing.map(&:last)).index_by(&:id)
        variants = Spree::Variant.with_deleted.where(id: missing.map(&:first)).index_by(&:id)

        missing.each do |variant_id, stock_location_id|
          location = locations[stock_location_id]
          variant = variants[variant_id]
          next if location.nil? || variant.nil?

          levels[[variant_id, stock_location_id]] = location.stock_level_or_create(variant)
        end

        levels.values
      end

      def awaited_pairs
        incoming_purchase_order_lines.distinct.pluck(:variant_id, "#{Spree::PurchaseOrder.table_name}.destination_location_id") |
          incoming_transfer_lines.distinct.pluck(:variant_id, "#{Spree::StockTransfer.table_name}.destination_location_id")
      end
    end
  end
end
