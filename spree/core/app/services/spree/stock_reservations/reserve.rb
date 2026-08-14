module Spree
  module StockReservations
    class Reserve
      prepend Spree::ServiceModule::Base

      def call(cart: nil, order: nil)
        if order
          Spree::Deprecation.warn('Calling Spree::StockReservations::Reserve with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        return success(cart) unless Spree::StorePreferences.read(cart&.store, :stock_reservations_enabled)

        expires_at = Time.current + Spree::StockReservation.ttl_for(cart)

        ApplicationRecord.transaction do
          targets = build_targets(cart)
          break if targets.empty?

          # Pessimistic lock + fresh read of count_on_hand. The lock serializes
          # concurrent checkouts and we use the locked rows below so we never
          # check stock against a stale association cache.
          locked_stock_levels = Spree::StockLevel
            .where(id: targets.map { |_, si| si.id })
            .lock
            .index_by(&:id)

          held = held_by_others(locked_stock_levels.keys, cart)
          existing = existing_reservations_for(targets)

          this_order_used = Hash.new(0)

          targets.each do |line_item, stock_level|
            stock_level = locked_stock_levels.fetch(stock_level.id)
            available = stock_level.count_on_hand - held.fetch(stock_level.id, 0) - this_order_used[stock_level.id]

            if available < line_item.quantity
              raise InsufficientStockError.new(
                line_item,
                Spree.t(
                  :insufficient_stock_for_reservation,
                  default: '%{item} has only %{available} available',
                  item: line_item.variant.name,
                  available: [available, 0].max
                )
              )
            end

            this_order_used[stock_level.id] += line_item.quantity

            reservation = existing[[stock_level.id, line_item.id]] ||
                          Spree::StockReservation.new(stock_level: stock_level, line_item: line_item)
            if cart.is_a?(Spree::Cart)
              reservation.cart = cart
              reservation.order = nil
            else
              reservation.order = cart
              reservation.cart = nil
            end
            reservation.quantity = line_item.quantity
            reservation.expires_at = expires_at
            reservation.save!
          end
        end

        success(cart)
      rescue InsufficientStockError => e
        failure(e.line_item, e.message)
      end

      private

      def build_targets(cart)
        cart.line_items.includes(variant: { stock_levels: :stock_location }).filter_map do |line_item|
          variant = line_item.variant
          next unless variant&.should_track_inventory?

          stock_level = select_stock_level(variant)
          # Backorderable and pre-cart variants oversell past count_on_hand,
          # so a reservation capped at on-hand stock would wrongly reject them;
          # their cap is enforced by Stock::Quantifier#can_supply? instead.
          next if stock_level.nil? || stock_level.backorderable? || variant.preorder?

          [line_item, stock_level]
        end
      end

      def select_stock_level(variant)
        variant.stock_levels.detect { |si| si.stock_location&.active? && si.available? }
      end

      def held_by_others(stock_level_ids, owner)
        return {} if stock_level_ids.empty?

        owner_column = owner.is_a?(Spree::Cart) ? :cart_id : :order_id
        Spree::StockReservation
          .active
          .where(stock_level_id: stock_level_ids)
          .where.not(owner_column => owner.id)
          .group(:stock_level_id)
          .sum(:quantity)
      end

      # One SELECT for all (stock_level_id, line_item_id) pairs we need to
      # upsert. Returns a hash keyed by [stock_level_id, line_item_id].
      def existing_reservations_for(targets)
        return {} if targets.empty?

        stock_level_ids = targets.map { |_, si| si.id }
        line_item_ids = targets.map { |li, _| li.id }

        Spree::StockReservation
          .where(stock_level_id: stock_level_ids, line_item_id: line_item_ids)
          .index_by { |r| [r.stock_level_id, r.line_item_id] }
      end
    end
  end
end
