module Spree
  module StockReservations
    class Release
      prepend Spree::ServiceModule::Base

      def call(order:)
        Spree::StockReservation.where(order_id: order.id).delete_all
        success(order)
      end
    end
  end
end
