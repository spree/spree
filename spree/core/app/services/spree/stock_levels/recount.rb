module Spree
  module StockLevels
    # Recomputes `reserved_count` and `incoming_count` on every stock level
    # from their sources — active checkout reservations, and the awaited units
    # on open purchase orders and in-flight transfers bound for the level's
    # location — and rewrites any row whose stored figure differs.
    #
    # The writers keep the counters right; this is the repair for when one of
    # them did not, and the backfill for installs that predate the columns.
    # Idempotent: a second run finds nothing to correct.
    class Recount
      prepend Spree::ServiceModule::Base

      OPEN_PURCHASE_ORDER_STATUSES = %w[ordered partially_received].freeze
      IN_FLIGHT_TRANSFER_STATUSES = %w[in_transit partially_received].freeze

      # @return [Spree::ServiceModule::Result] value is the list of corrected
      #   rows: `{ stock_level:, reserved: [was, now], incoming: [was, now] }`
      def call
        reserved = expected_reserved
        incoming = expected_incoming

        corrected = candidate_levels(reserved, incoming).filter_map do |stock_level|
          expected = {
            reserved_count: reserved.fetch(stock_level.id, 0),
            incoming_count: incoming.fetch([stock_level.variant_id, stock_level.stock_location_id], 0)
          }
          next if expected == stock_level.slice(:reserved_count, :incoming_count).symbolize_keys

          correction = {
            stock_level: stock_level,
            reserved: [stock_level.reserved_count, expected[:reserved_count]],
            incoming: [stock_level.incoming_count, expected[:incoming_count]]
          }
          stock_level.update_columns(expected)
          correction
        end

        success(corrected)
      end

      private

      def expected_reserved
        Spree::StockReservation.active.group(:stock_level_id).sum(:quantity)
      end

      # Keyed by (variant, destination location), which is what a level is.
      # Summed in Ruby so the recount shares `ReceivableItem#incoming` with the
      # writers rather than restating it in SQL.
      def expected_incoming
        totals = Hash.new(0)

        open_purchase_order_lines.find_each do |item|
          totals[[item.variant_id, item.purchase_order.destination_location_id]] += item.incoming
        end
        in_flight_transfer_lines.find_each do |item|
          totals[[item.variant_id, item.stock_transfer.destination_location_id]] += item.incoming
        end

        totals.reject { |_, units| units.zero? }
      end

      def open_purchase_order_lines
        Spree::PurchaseOrderItem.joins(:purchase_order).includes(:purchase_order)
                                .where(Spree::PurchaseOrder.table_name => { status: OPEN_PURCHASE_ORDER_STATUSES })
      end

      def in_flight_transfer_lines
        Spree::StockTransferItem.joins(:stock_transfer).includes(:stock_transfer)
                                .where(Spree::StockTransfer.table_name => { status: IN_FLIGHT_TRANSFER_STATUSES })
      end

      # Every level that holds a figure, plus every level a source says should
      # — created where the warehouse has never held the SKU, as the writers
      # would have.
      def candidate_levels(reserved, incoming)
        levels = Spree::StockLevel.where.not(reserved_count: 0)
                                  .or(Spree::StockLevel.where.not(incoming_count: 0))
                                  .or(Spree::StockLevel.where(id: reserved.keys))
                                  .to_a

        incoming.each_key do |variant_id, stock_location_id|
          next if levels.any? { |level| level.variant_id == variant_id && level.stock_location_id == stock_location_id }

          location = Spree::StockLocation.find_by(id: stock_location_id)
          variant = Spree::Variant.with_deleted.find_by(id: variant_id)
          next if location.nil? || variant.nil?

          levels << location.stock_level_or_create(variant)
        end

        levels.uniq(&:id)
      end
    end
  end
end
