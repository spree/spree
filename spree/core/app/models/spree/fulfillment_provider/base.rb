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

        # Human-readable name for admin UIs. Provider gems follow the
        # `SpreeEasyPost::DeliveryRateProvider` convention, where demodulizing
        # yields the useless class name ("Delivery Rate Provider") — so those
        # derive the label from the gem's outer module instead
        # (`SpreeEasyPost` → "EasyPost"), matching Spree::Integration.api_type.
        #
        # @return [String]
        def provider_name
          leaf = name.demodulize
          outer = name.deconstantize.delete_prefix('Spree')

          return leaf.titleize if outer.blank? || !leaf.end_with?('Provider')

          # Not `titleize` — it would split the gem's own casing
          # ("SpreeEasyPost" → "Easy Post"). Brands that need more than the
          # module name override this method.
          outer.delete_prefix('::')
        end

        # The Spree::Integration subclass holding this provider's credentials,
        # as a class name string — same contract as
        # {Spree::DeliveryRateProvider::Base.integration_class}. Providers
        # without external credentials leave it nil.
        #
        # @return [String, nil]
        def integration_class
          nil
        end

        # Whether the store can use this provider — false while a carrier
        # provider's integration is unconnected. Admin UIs surface it as a
        # connect prompt rather than hiding the provider, so the merchant can
        # see what a connection would unlock.
        #
        # @param store [Spree::Store, nil]
        # @return [Boolean]
        def available_for_store?(store)
          return true if integration_class.blank?

          store.present? && store.integrations.active.exists?(type: integration_class)
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
