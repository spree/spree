module Spree
  module StockReservations
    # Re-runs Reserve after a line-item mutation while the order is mid-checkout.
    # No-op when the order is in `cart`, `complete`, or `canceled` — those states
    # don't need active reservation tracking.
    class Refresh
      prepend Spree::ServiceModule::Base

      def call(order:)
        return success(order) if order.cart? || order.complete? || order.canceled?

        Spree::StockReservations::Reserve.call(order: order)
        success(order)
      end
    end
  end
end
