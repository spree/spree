module Spree
  module Carts
    class SetQuantity
      prepend Spree::ServiceModule::Base

      def call(cart: nil, order: nil, line_item: nil, quantity: nil)
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::SetQuantity with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        rewrite_input!(remove: [:order], cart: cart)
        ActiveRecord::Base.transaction do
          run :change_item_quantity
          run :handle_stock_reservations
          run Spree.cart_recalculate_workflow
        end
      end

      private

      def change_item_quantity(cart:, line_item:, quantity: nil)
        return failure(line_item) unless line_item.update(quantity: quantity)

        success(cart: cart, line_item: line_item)
      end

      def handle_stock_reservations(cart:, line_item:)
        if cart.in_checkout?
          result = Spree::StockReservations::Reserve.call(cart: cart)
          return failure(line_item, result.error) if result.failure?
        end

        success(cart: cart, line_item: line_item)
      end
    end
  end
end
