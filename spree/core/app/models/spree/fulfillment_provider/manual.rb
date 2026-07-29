module Spree
  module FulfillmentProvider
    # Default provider — admin-driven fulfillment with no provider-side
    # mechanics (tracking numbers are entered by hand).
    class Manual < Base
      def create_fulfillment(_fulfillment)
        {}
      end

      def cancel_fulfillment(_fulfillment)
        true
      end
    end
  end
end
