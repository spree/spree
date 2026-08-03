module Spree
  module Carts
    class RemoveLineItem
      prepend Spree::ServiceModule::Base

      def call(cart: nil, order: nil, line_item: nil, options: nil)
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::RemoveLineItem with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        options ||= {}
        ActiveRecord::Base.transaction do
          cart.line_items.destroy(line_item)

          # LineItem dependent: :destroy removes its own reservation row;
          # remaining items may need a fresh reservation pass when in checkout.
          if cart.in_checkout? && cart.line_items.any?
            result = Spree::StockReservations::Reserve.call(cart: cart)
            raise Spree::StockReservations::InsufficientStockError.new(nil, result.error.to_s) if result.failure?
          end

          Spree.cart_recalculate_workflow.new.call(cart: cart,
                                                  line_item: line_item,
                                                  options: options)
        end
        success(line_item)
      rescue Spree::StockReservations::InsufficientStockError => e
        failure(line_item, e.message)
      end
    end
  end
end
