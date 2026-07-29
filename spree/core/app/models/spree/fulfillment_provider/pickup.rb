module Spree
  module FulfillmentProvider
    # Merchant-location pickup: hand-over is confirmed by staff, no
    # provider-side mechanics.
    class Pickup < Base
      def create_fulfillment(_fulfillment)
        {}
      end

      def cancel_fulfillment(_fulfillment)
        true
      end
    end
  end
end
