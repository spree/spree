module Spree
  module StockReservations
    class Reserve
      prepend Spree::ServiceModule::Base

      class InsufficientStock < StandardError
        attr_reader :line_item, :message

        def initialize(line_item, message)
          @line_item = line_item
          @message = message
          super(message)
        end
      end

      def call(order:)
        return success(order) unless Spree::Config[:stock_reservations_enabled]

        expires_at = Time.current + Spree::StockReservation.ttl_for(order)

        ApplicationRecord.transaction do
          targets = build_targets(order)
          stock_item_ids = targets.map { |_, stock_item| stock_item.id }
          # Pessimistic lock prevents two concurrent checkouts from both passing
          # the availability check on the same stock_item.
          Spree::StockItem.where(id: stock_item_ids).lock.to_a if stock_item_ids.any?
          held = held_by_others(stock_item_ids, order.id)

          targets.each do |line_item, stock_item|
            available = stock_item.count_on_hand - held.fetch(stock_item.id, 0)
            if available < line_item.quantity
              raise InsufficientStock.new(
                line_item,
                Spree.t(
                  :insufficient_stock_for_reservation,
                  default: '%{item} has only %{available} available',
                  item: line_item.variant.name,
                  available: [available, 0].max
                )
              )
            end

            reservation = Spree::StockReservation.find_or_initialize_by(
              stock_item: stock_item,
              line_item: line_item
            )
            reservation.order = order
            reservation.quantity = line_item.quantity
            reservation.expires_at = expires_at
            reservation.save!
          end
        end

        success(order)
      rescue InsufficientStock => e
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
    end
  end
end
