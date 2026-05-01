module Spree
  module StockReservations
    class Extend
      prepend Spree::ServiceModule::Base

      def call(order:)
        return success(order) unless Spree::Config[:stock_reservations_enabled]

        expires_at = Time.current + Spree::StockReservation.ttl_for(order)

        Spree::StockReservation
          .where(order_id: order.id)
          .update_all(expires_at: expires_at, updated_at: Time.current)

        success(order)
      end
    end
  end
end
