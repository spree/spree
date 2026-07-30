module Spree
  module StockReservations
    class Release
      prepend Spree::ServiceModule::Base

      def call(owner: nil, cart: nil, order: nil)
        cart = owner || cart || order
        Spree::StockReservation.merge(Spree::StockReservation.for_order(cart)).delete_all
        success(cart)
      end
    end
  end
end
