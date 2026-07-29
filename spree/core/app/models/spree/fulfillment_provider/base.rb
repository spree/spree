module Spree
  module FulfillmentProvider
    # Strategy handling create/track/cancel mechanics per fulfillment type.
    # Stored as a string class name on DeliveryMethod, constantized at call
    # time; registered via Spree.fulfillment_providers. Replaces the legacy
    # ShipmentHandler name-constantize mechanism.
    class Base
      # @return [Boolean] whether the fulfillment may transition to fulfilled
      def can_fulfill?(_fulfillment)
        true
      end

      # Whether fulfillments handled by this provider fulfill themselves on
      # order completion (digital delivery).
      def auto_fulfill?
        false
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
