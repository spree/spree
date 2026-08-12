module Spree
  module StockReservations
    class Extend
      prepend Spree::ServiceModule::Base

      def call(cart: nil, order: nil)
        if order
          Spree::Deprecation.warn('Calling Spree::StockReservations::Extend with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        return success(cart) unless Spree::StorePreferences.read(cart&.store, :stock_reservations_enabled)

        expires_at = Time.current + Spree::StockReservation.ttl_for(cart)

        Spree::StockReservation
          .merge(Spree::StockReservation.for_order(cart))
          .update_all(expires_at: expires_at, updated_at: Time.current)

        success(cart)
      end
    end
  end
end
