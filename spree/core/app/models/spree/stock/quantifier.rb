module Spree
  module Stock
    class Quantifier
      attr_reader :variant, :stock_location, :excluded_order

      # @param excluded_order [Spree::Cart, Spree::Order, nil] when given,
      #   reservations belonging to this cart/order are not counted against
      #   availability. Used when checking a cart's own line items so the
      #   customer's own checkout hold doesn't make their item look out of
      #   stock.
      def initialize(variant, stock_location = nil, excluded_order: nil)
        @variant         = variant
        @stock_location  = stock_location
        @excluded_order  = excluded_order
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
      # In Spree 5.5 {Spree::StockLevel#allocated_count} is a Ruby shim that
      # always returns 0, so this equals +SUM(count_on_hand)+. In 6.0
      # (Typed Stock Movements) +allocated_count+ becomes a real column and
      # the SQL path subtracts it natively.
      #
      # @return [Integer] units available before checkout reservations
      def available_stock
        if association_loaded?
          stock_levels.sum(&:available_count)
        elsif self.class.allocated_count_column?
          stock_levels.sum('count_on_hand - allocated_count')
        else
          stock_levels.sum(:count_on_hand)
        end
      end

      # Units currently held by active checkout reservations on the
      # location-filtered stock items. Returns 0 when stock reservations
      # are globally disabled.
      #
      # Reads through the same {#stock_levels} collection as {#available_stock}
      # so a per-location query (filtered by `stock_location`) only counts
      # reservations that belong to those same stock items — otherwise a
      # multi-location variant would subtract reservations from other
      # warehouses.
      #
      # When +excluded_order+ is set, that order's own reservations are left
      # out of the count so an order's own checkout hold doesn't count
      # against the availability of its own line items.
      #
      # @return [Integer]
      def reserved_quantity
        return @reserved_quantity if defined?(@reserved_quantity)
        return @reserved_quantity = 0 unless reservations_enabled?
        return @reserved_quantity = 0 if stock_levels.blank?

        excluded_owner_key = excluded_order.is_a?(Spree::Cart) ? :cart_id : :order_id
        excluded_owner_id = excluded_order&.id

        @reserved_quantity = if reservations_preloaded?
                               stock_levels.sum do |si|
                                 reservations = si.active_stock_reservations
                                 reservations = reservations.reject { |r| r.public_send(excluded_owner_key) == excluded_owner_id } if excluded_owner_id
                                 reservations.sum(&:quantity)
                               end
                             else
                               reservations = Spree::StockReservation.active.where(stock_level_id: stock_levels.map(&:id))
                               reservations = reservations.where.not(excluded_owner_key => excluded_owner_id) if excluded_owner_id
                               reservations.sum(:quantity)
                             end
      end

      # Check if any of variant stock items is backorderable
      def backorderable?
        @backorderable ||= stock_levels.any?(&:backorderable)
      end

      # Whether the requested quantity can be supplied. Beyond on-hand stock a
      # variant may oversell two ways: +backorderable+ stock, or a pre-order
      # (which also lifts the publish gate for a scheduled launch). Either way
      # the variant's +backorder_limit+ caps how far below zero it may go; a nil
      # (empty) limit means unlimited.
      def can_supply?(required = 1)
        return false unless variant.available? || variant.preorder?
        return true unless variant.should_track_inventory?

        oversellable = backorderable? || variant.preorder?
        limit = variant.backorder_limit
        return true if oversellable && limit.nil?

        # On-hand stock, plus — for a capped oversell — the room to sell below
        # zero down to +-backorder_limit+ (a single clamp of signed on-hand plus
        # the limit).
        supplyable = if oversellable
                       [available_stock - reserved_quantity + limit, 0].max
                     else
                       total_on_hand
                     end
        supplyable >= required
      end

      def stock_levels
        @stock_levels ||= scope_to_location(variant.stock_levels)
      end

      # Memoized schema check so {#available_stock} doesn't introspect the
      # column list on every call. Flips from false → true when 6.0 Typed
      # Stock Movements adds the `allocated_count` column.
      #
      # @return [Boolean]
      def self.allocated_count_column?
        return @allocated_count_column if defined?(@allocated_count_column)

        @allocated_count_column = Spree::StockLevel.connection.column_exists?(:spree_stock_levels, :allocated_count)
      end

      private

      # The stock location owns a store directly; otherwise the variant's
      # product does. Both can be absent, in which case the declared default
      # applies.
      def reservations_enabled?
        store = stock_location&.store || variant&.product&.store
        Spree::StorePreferences.read(store, :stock_reservations_enabled)
      end

      def association_loaded?
        variant.association(:stock_levels).loaded?
      end

      def reservations_preloaded?
        association_loaded? &&
          stock_levels.all? { |si| si.association(:active_stock_reservations).loaded? }
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
