module Spree
  module Stock
    class Quantifier
      attr_reader :variant, :stock_location, :excluded_order, :provided_stock_levels

      # @param excluded_order [Spree::Cart, Spree::Order, nil] when given,
      #   reservations belonging to this cart/order are not counted against
      #   availability. Used when checking a cart's own line items so the
      #   customer's own checkout hold doesn't make their item look out of
      #   stock.
      # @param stock_levels [Enumerable<Spree::StockLevel>, nil] rows to count
      #   instead of the variant's own. Passed by the inventory provider when
      #   stock lives in an external system; the rows may be unsaved.
      def initialize(variant, stock_location = nil, excluded_order: nil, stock_levels: nil)
        @variant         = variant
        @stock_location  = stock_location
        @excluded_order  = excluded_order
        @provided_stock_levels = stock_levels
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
      # variant's active stock levels.
      #
      # @return [Integer] units available before checkout reservations
      def available_stock
        if association_loaded?
          stock_levels.sum(&:available_count)
        else
          stock_levels.sum('count_on_hand - allocated_count')
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
                               reservations = Spree::StockReservation.active.where(stock_level_id: persisted_stock_level_ids)
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
        @stock_levels ||= scope_to_location(provided_stock_levels || variant.stock_levels)
      end

      # Reservations hang off Spree's own rows, so an external provider's
      # unsaved rows carry no id to match on. Resolve them by (variant,
      # location) instead: a checkout hold is Spree's to honour whoever owns
      # the stock figure, and matching on a nil id would silently subtract
      # nothing and oversell the hold.
      #
      # @return [Array<Integer>]
      def persisted_stock_level_ids
        ids = stock_levels.map(&:id).compact
        return ids if ids.length == stock_levels.size

        locations = stock_levels.map(&:stock_location_id).compact
        return ids if locations.empty?

        ids | Spree::StockLevel.where(variant_id: variant.id, stock_location_id: locations).ids
      end

      private

      # The stock location owns a store directly; otherwise the variant's
      # product does. Both can be absent, in which case the declared default
      # applies.
      def reservations_enabled?
        store = stock_location&.store || variant&.product&.store
        Spree::StorePreferences.read(store, :stock_reservations_enabled)
      end

      # Whether the rows being counted are already in memory. Injected provider
      # rows always are — they are a plain Array with no association to ask, and
      # an empty one is a complete answer (the variant is unknown to that
      # system), not a signal to fall back to the local records.
      def association_loaded?
        return true unless provided_stock_levels.nil?

        variant.association(:stock_levels).loaded?
      end

      # association_loaded? first: it is a memory check, while stock_levels
      # loads the relation. An external provider's rows are new records whose
      # reservation association reads as empty rather than unloaded, which
      # would count every local hold as zero — force those down the query path.
      def reservations_preloaded?
        return false unless association_loaded?
        return false if stock_levels.any?(&:new_record?)

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
