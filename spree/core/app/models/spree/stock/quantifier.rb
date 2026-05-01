module Spree
  module Stock
    class Quantifier
      attr_reader :variant, :stock_location

      def initialize(variant, stock_location = nil)
        @variant        = variant
        @stock_location = stock_location
      end

      def total_on_hand
        @total_on_hand ||= if variant.should_track_inventory?
                             raw_count_on_hand - reserved_quantity
                           else
                             BigDecimal::INFINITY
                           end
      end

      # Physical count without reservations (admin/reporting).
      def raw_count_on_hand
        if association_loaded?
          stock_items.sum(&:count_on_hand)
        else
          stock_items.sum(:count_on_hand)
        end
      end

      def stock_item_ids
        @stock_item_ids ||= stock_items.map(&:id)
      end

      # Units currently held by active reservations across this variant's stock items.
      # Short-circuits the SUM query with an EXISTS check so non-checkout product
      # list traffic stays one-query-per-variant.
      def reserved_quantity
        return @reserved_quantity if defined?(@reserved_quantity)
        return @reserved_quantity = 0 unless Spree::Config[:stock_reservations_enabled]

        active_reservations = Spree::StockReservation.active.where(stock_item_id: stock_item_ids)
        @reserved_quantity = active_reservations.exists? ? active_reservations.sum(:quantity) : 0
      end

      def backorderable?
        @backorderable ||= stock_items.any?(&:backorderable)
      end

      def can_supply?(required = 1)
        variant.available? && (backorderable? || total_on_hand >= required)
      end

      def stock_items
        @stock_items ||= scope_to_location(variant.stock_items)
      end

      private

      def association_loaded?
        variant.association(:stock_items).loaded?
      end

      def scope_to_location(collection)
        if stock_location.blank?
          if association_loaded?
            return collection.select { |si| si.stock_location&.active? }
          else
            return collection.with_active_stock_location
          end
        end

        if association_loaded?
          collection.select { |si| si.stock_location_id == stock_location.id }
        else
          collection.where(stock_location: stock_location)
        end
      end
    end
  end
end
