module Spree
  module StockReservations
    class Reserve
      prepend Spree::ServiceModule::Base

      def call(order:)
        return success(order) unless Spree::Config[:stock_reservations_enabled]

        expires_at = Time.current + Spree::StockReservation.ttl_for(order)

        ApplicationRecord.transaction do
          targets = build_targets(order)
          break if targets.empty?

          # Pessimistic lock + fresh read of count_on_hand. The lock serializes
          # concurrent checkouts and we use the locked rows below so we never
          # check stock against a stale association cache.
          locked_stock_items = Spree::StockItem
            .where(id: targets.map { |_, si| si.id })
            .lock
            .index_by(&:id)

          held = held_by_others(locked_stock_items.keys, order.id)
          existing = existing_reservations_for(targets)

          this_order_used = Hash.new(0)

          targets.each do |line_item, stock_item|
            stock_item = locked_stock_items.fetch(stock_item.id)
            available = stock_item.count_on_hand - held.fetch(stock_item.id, 0) - this_order_used[stock_item.id]

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

            this_order_used[stock_item.id] += line_item.quantity

            reservation = existing[[stock_item.id, line_item.id]] ||
                          Spree::StockReservation.new(stock_item: stock_item, line_item: line_item)
            reservation.order = order
            reservation.quantity = line_item.quantity
            reservation.expires_at = expires_at
            reservation.save!
          end
        end

        success(order)
      rescue InsufficientStockError => e
        failure(e.line_item, e.message)
      end

      private

      def build_targets(order)
        order.line_items.includes(variant: { stock_items: :stock_location }).filter_map do |line_item|
          variant = line_item.variant
          next unless variant&.should_track_inventory?

          stock_item = select_stock_item(variant)
          next if stock_item.nil? || stock_item.backorderable?

          [line_item, stock_item]
        end
      end

      def select_stock_item(variant)
        variant.stock_items.detect { |si| si.stock_location&.active? && si.available? }
      end

      def held_by_others(stock_item_ids, exclude_order_id)
        return {} if stock_item_ids.empty?

        Spree::StockReservation
          .active
          .where(stock_item_id: stock_item_ids)
          .where.not(order_id: exclude_order_id)
          .group(:stock_item_id)
          .sum(:quantity)
      end

      # One SELECT for all (stock_item_id, line_item_id) pairs we need to
      # upsert. Returns a hash keyed by [stock_item_id, line_item_id].
      def existing_reservations_for(targets)
        return {} if targets.empty?

        stock_item_ids = targets.map { |_, si| si.id }
        line_item_ids = targets.map { |li, _| li.id }

        Spree::StockReservation
          .where(stock_item_id: stock_item_ids, line_item_id: line_item_ids)
          .index_by { |r| [r.stock_item_id, r.line_item_id] }
      end
    end
  end
end
