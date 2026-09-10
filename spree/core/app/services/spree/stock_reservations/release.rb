module Spree
  module StockReservations
    class Release
      prepend Spree::ServiceModule::Base

      def call(owner: nil, cart: nil, order: nil)
        cart = owner || cart || order
        Spree::StockReservation.withdraw(Spree::StockReservation.for_order(cart))
        success(cart)
      end
    end
  end
end
