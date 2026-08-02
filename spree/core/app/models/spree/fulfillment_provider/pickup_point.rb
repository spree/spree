module Spree
  module FulfillmentProvider
    # Third-party pickup point (parcel locker, service point). Point
    # discovery and validation live on the delivery method's
    # PickupPointProvider; hand-over mechanics default to manual.
    class PickupPoint < Base
      def self.fulfillment_types
        ['pickup_point']
      end

      def requires_address?
        false
      end

      def create_fulfillment(_fulfillment)
        {}
      end

      def cancel_fulfillment(_fulfillment)
        true
      end
    end
  end
end
