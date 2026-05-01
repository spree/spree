module Spree
  module StockReservations
    # Three-way dispatch on the cart→checkout transition:
    #   entering checkout (was_in_cart && !cart?) → Reserve
    #   mid-checkout mutation (!was_in_cart && !cart?) → Extend
    #   reverting to cart (!was_in_cart && cart?) → Release
    # No-op when the order was already in `cart` and stayed there.
    class Sync
      prepend Spree::ServiceModule::Base

      def call(order:, was_in_cart:)
        if order.cart?
          Spree::StockReservations::Release.call(order: order) unless was_in_cart
        elsif was_in_cart
          Spree::StockReservations::Reserve.call(order: order)
        else
          Spree::StockReservations::Extend.call(order: order)
        end

        success(order)
      end
    end
  end
end
