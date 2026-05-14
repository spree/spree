module Spree
  module Stock
    class Quantifier
      attr_reader :variant, :stock_location

      def initialize(variant, stock_location = nil)
        @variant        = variant
        @stock_location = stock_location
      end

      # Units a customer can purchase right now: physical pool minus
      # already-allocated units minus active checkout reservations. Clamped
      # at zero so callers never see a negative count.
      #
      # Returns +BigDecimal::INFINITY+ when the variant does not track
      # inventory (effectively unlimited supply).
      #
      # @return [Integer, BigDecimal] purchasable quantity, or +INFINITY+
      def total_on_hand
        @total_on_hand ||= if variant.should_track_inventory?
                             [available_stock - reserved_quantity, 0].max
                           else
                             BigDecimal::INFINITY
                           end
      end

      # Physical pool minus already-allocated units, summed across the
      # variant's active stock items.
      #
      # In Spree 5.5 {Spree::StockItem#allocated_count} is a Ruby shim that
      # always returns 0, so this equals +SUM(count_on_hand)+. In 6.0
      # (Typed Stock Movements) +allocated_count+ becomes a real column and
      # the SQL path subtracts it natively.
      #
      # @return [Integer] units available before checkout reservations
      def available_stock
        if association_loaded?
          stock_items.sum(&:available_count)
        elsif self.class.allocated_count_column?
          stock_items.sum('count_on_hand - allocated_count')
        else
          stock_items.sum(:count_on_hand)
        end
      end

      # Units currently held by active checkout reservations on the
      # location-filtered stock items. Returns 0 when stock reservations
      # are globally disabled.
      #
      # Reads through the same {#stock_items} collection as {#available_stock}
      # so a per-location query (filtered by `stock_location`) only counts
      # reservations that belong to those same stock items — otherwise a
      # multi-location variant would subtract reservations from other
      # warehouses.
      #
      # @return [Integer]
      def reserved_quantity
        return @reserved_quantity if defined?(@reserved_quantity)
        return @reserved_quantity = 0 unless Spree::Config[:stock_reservations_enabled]
        return @reserved_quantity = 0 if stock_items.blank?

        @reserved_quantity = if reservations_preloaded?
                               stock_items.sum { |si| si.active_stock_reservations.sum(&:quantity) }
                             else
                               Spree::StockReservation.active.where(stock_item_id: stock_items.map(&:id)).sum(:quantity)
                             end
      end

      # Check if any of variant stock items is backorderable
      def backorderable?
        @backorderable ||= stock_items.any?(&:backorderable)
      end

      def can_supply?(required = 1)
        variant.available? && (backorderable? || total_on_hand >= required)
      end

      def stock_items
        @stock_items ||= scope_to_location(variant.stock_items)
      end

      # Memoized schema check so {#available_stock} doesn't introspect the
      # column list on every call. Flips from false → true when 6.0 Typed
      # Stock Movements adds the `allocated_count` column.
      #
      # @return [Boolean]
      def self.allocated_count_column?
        return @allocated_count_column if defined?(@allocated_count_column)

        @allocated_count_column = Spree::StockItem.connection.column_exists?(:spree_stock_items, :allocated_count)
      end

      private

      def association_loaded?
        variant.association(:stock_items).loaded?
      end

      def reservations_preloaded?
        association_loaded? &&
          stock_items.all? { |si| si.association(:active_stock_reservations).loaded? }
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
