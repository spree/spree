module Spree
  module Cart
    class SetQuantity
      prepend Spree::ServiceModule::Base

      def call(order:, line_item:, quantity: nil)
        ActiveRecord::Base.transaction do
          run :change_item_quantity
          run :handle_stock_reservations
          run Spree.cart_recalculate_service
        end
      end

      private

      def change_item_quantity(order:, line_item:, quantity: nil)
        return failure(line_item) unless line_item.update(quantity: quantity)

        success(order: order, line_item: line_item)
      end

      def handle_stock_reservations(order:, line_item:)
        if order.in_checkout?
          result = Spree::StockReservations::Reserve.call(order: order)
          return failure(line_item, result.error) if result.failure?
        end

        success(order: order, line_item: line_item)
      end
    end
  end
end
