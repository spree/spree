module Spree
  module FulfillmentProvider
    # Strategy handling create/track/cancel mechanics per fulfillment type.
    # Stored as a string class name on DeliveryMethod, constantized at call
    # time; registered via Spree.fulfillment_providers. Replaces the legacy
    # ShipmentHandler name-constantize mechanism.
    class Base
      include Spree::IntegrationBackedProvider

      class << self
        # Behavior predicates — the class hierarchy IS the vocabulary.
        # Subclasses override the one that describes their mechanics; admin
        # UIs and profile kinds compose against these, never string lists.
        def digital?
          false
        end

        def pickup?
          false
        end

        def pickup_point?
          false
        end

        # Whether this provider produces shipping labels (and so supports the
        # explicit buy-label step before fulfilling). Carrier gems override.
        def generates_labels?
          false
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

      # Whether packages originating from this stock location may use the
      # method — answered by the method's origin group (no group or no
      # members means every location). Pickup overrides with its own policy
      # semantics (pickup-enabled counters, ship-to-store transfers).
      def serves_location?(delivery_method, stock_location)
        group = delivery_method.delivery_origin_group
        return true if group.nil?

        group.covers_location?(stock_location)
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

      private

      # The connected, active integration carrying this provider's
      # credentials, resolved from the fulfillment's store.
      #
      # @param fulfillment [Spree::Fulfillment]
      # @return [Spree::Integration, nil]
      def integration_for(fulfillment)
        return if self.class.integration_class.blank?

        store = fulfillment.order&.store || fulfillment.cart&.store
        store&.integrations&.active&.find_by(type: self.class.integration_class)
      end
    end
  end
end
