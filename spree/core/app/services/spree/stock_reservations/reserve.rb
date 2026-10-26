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

          # Pessimistic lock + fresh read of count_on_hand. The lock serializes
          # concurrent checkouts and we use the locked rows below so we never
          # check stock against a stale association cache. The shelves held
          # now are locked with the new ones, in id order, so two checkouts
          # moving holds past each other cannot deadlock.
          stock_level_ids = targets.map { |_, si, _| si.id } |
                            Spree::StockReservation.for_order(cart).pluck(:stock_level_id)
          locked_stock_levels = Spree::StockLevel
            .where(id: stock_level_ids)
            .order(:id)
            .lock
            .index_by(&:id)

          held = held_by_others(locked_stock_levels.keys, cart)
          existing = existing_reservations_for(targets)

          this_order_used = Hash.new(0)

          reservations = targets.map do |line_item, stock_level, quantity|
            stock_level = locked_stock_levels.fetch(stock_level.id)
            available = stock_level.available_count - held.fetch(stock_level.id, 0) - this_order_used[stock_level.id]

            raise_insufficient_stock(line_item, available) if available < quantity

            this_order_used[stock_level.id] += quantity

            reservation = existing[[stock_level.id, line_item.id]] ||
                          Spree::StockReservation.new(stock_level: stock_level, line_item: line_item)
            if cart.is_a?(Spree::Cart)
              reservation.cart = cart
              reservation.order = nil
            else
              reservation.order = cart
              reservation.cart = nil
            end
            reservation.quantity = quantity
            reservation.expires_at = expires_at
            reservation.save!
            reservation
          end

          # Left in place, a hold the allocation moved away from blocks other buyers until it expires.
          moved = Spree::StockReservation.for_order(cart).where.not(id: reservations.map(&:id))
          Spree::StockReservation.withdraw(moved)
        end

        success(cart)
      rescue InsufficientStockError => e
        failure(e.line_item, e.message)
      end

      private

      # Held where the allocation packs each unit, so the hold protects the stock the order will ship.
      def build_targets(cart)
        cart.line_items.reset
        packages = Spree::Stock::Coordinator.new(cart).allocated_packages
        items = packages.flat_map { |package| package.contents.map { |item| [package.stock_location, item] } }
        stock_levels = Spree::Stock::Packer.stock_levels_by_location(packages.map(&:stock_location).uniq,
                                                                     cart.line_items.map(&:variant_id).uniq)

        check_allocated_in_full(cart, items)

        # Summed because a splitter can pack one line into several packages from one location.
        quantities = Hash.new(0)
        items.each do |stock_location, item|
          next unless item.on_hand?

          line_item = item.inventory_unit.line_item
          variant = line_item.variant
          stock_level = stock_levels.dig(stock_location.id, variant.id)
          # Backorderable and pre-cart variants oversell past count_on_hand,
          # so a reservation capped at on-hand stock would wrongly reject them;
          # their cap is enforced by Stock::Quantifier#can_supply? instead.
          next unless variant.should_track_inventory?
          next if stock_level.nil? || stock_level.backorderable? || variant.preorder?

          quantities[[line_item, stock_level]] += item.quantity
        end

        quantities.map { |(line_item, stock_level), quantity| [line_item, stock_level, quantity] }
      end

      # A line placed nowhere is left to the delivery check, which can say why;
      # one placed in part has shelves that fall short, and is refused.
      def check_allocated_in_full(cart, items)
        allocated = items.each_with_object(Hash.new(0)) do |(_, item), quantities|
          quantities[item.inventory_unit.line_item_id] += item.quantity
        end

        cart.line_items.each do |line_item|
          variant = line_item.variant
          next unless variant&.should_track_inventory?
          next if variant.preorder?

          placed = allocated[line_item.id]
          raise_insufficient_stock(line_item, placed) if placed.positive? && placed < line_item.quantity
        end
      end

      def raise_insufficient_stock(line_item, available)
        raise InsufficientStockError.new(
          line_item,
          I18n.t(
            'spree.insufficient_stock_for_reservation',
            item: line_item.variant.name,
            available: [available, 0].max
          )
        )
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

        stock_level_ids = targets.map { |_, si, _| si.id }
        line_item_ids = targets.map { |li, _, _| li.id }

        Spree::StockReservation
          .where(stock_level_id: stock_level_ids, line_item_id: line_item_ids)
          .index_by { |r| [r.stock_level_id, r.line_item_id] }
      end
    end
  end
end
