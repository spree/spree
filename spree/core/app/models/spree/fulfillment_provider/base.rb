module Spree
  module FulfillmentProvider
    # Strategy handling create/track/cancel mechanics per fulfillment type.
    # Stored as a string class name on DeliveryMethod, constantized at call
    # time; registered via Spree.fulfillment_providers. Replaces the legacy
    # ShipmentHandler name-constantize mechanism.
    class Base
      class << self
        # Fulfillment types this provider can handle, so admin UIs can offer
        # only the providers that fit the chosen type. An empty list means
        # "any type".
        #
        # @return [Array<String>]
        def fulfillment_types
          []
        end

        # @return [String] human-readable name for admin UIs
        def provider_name
          name.demodulize.titleize
        end
      end

      # @return [Boolean] whether the fulfillment may transition to fulfilled
      def can_fulfill?(_fulfillment)
        true
      end

      # Whether fulfillments handled by this provider fulfill themselves on
      # order completion (digital delivery).
      def auto_fulfill?
        false
      end

      # Whether this provider dispatches to a customer shipping address.
      # Address-free providers (digital, the pickup kinds) override to false;
      # it also drives delivery-zone checks, which describe the customer
      # destination.
      def requires_address?
        true
      end

      # Whether the method can serve a package sourced from the given stock
      # location. Shipping-like providers dispatch from anywhere; merchant
      # pickup overrides this to require an eligible pickup location.
      def serves_location?(_delivery_method, _stock_location)
        true
      end

      # Performs the provider-side dispatch when a fulfillment fulfills.
      #
      # @return [Hash] optionally { tracking_number:, tracking_url: }
      def create_fulfillment(_fulfillment)
        raise NotImplementedError, "Please implement 'create_fulfillment' in your fulfillment provider: #{self.class.name}"
      end

      # Cancels the provider-side dispatch.
      def cancel_fulfillment(_fulfillment)
        raise NotImplementedError, "Please implement 'cancel_fulfillment' in your fulfillment provider: #{self.class.name}"
      end

      # @return [String, nil] provider-computed tracking URL
      def tracking_url(_fulfillment)
        nil
      end

      # @return [Array] provider documents (labels, customs forms, ...)
      def documents(_fulfillment)
        []
      end
    end
  end
end
