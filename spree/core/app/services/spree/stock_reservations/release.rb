module Spree
  module StockReservations
    class Release
      prepend Spree::ServiceModule::Base

      def call(order:)
        Spree::StockReservation.merge(Spree::StockReservation.for_order(order)).delete_all
        success(order)
      end
    end
  end
end
