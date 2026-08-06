module Spree
  module DeliveryRateProvider
    # Strategy that answers "what does this delivery method cost for this
    # package, and what metadata comes with the quote?".
    #
    # Stored as a string class name on DeliveryMethod and constantized at call
    # time; registered via Spree.delivery_rate_providers. The Estimator
    # dispatches here in place of calling the calculator directly, so
    # filtering, VAT gross-up, tax resolution and sorting stay in one place
    # for every provider.
    #
    # External providers resolve credentials through the delivery method's
    # store integration — they never store credentials themselves.
    class Base
      attr_reader :delivery_method

      class << self
        # @return [String] human-readable name for admin UIs
        def provider_name
          name.demodulize.titleize
        end

        # The Spree::Integration subclass holding this provider's credentials,
        # as a class name string. Internal providers need none.
        #
        # @return [String, nil]
        def integration_class
          nil
        end

        # Whether the store can use this provider at all — admin UIs hide
        # providers whose integration isn't connected, and DeliveryMethod
        # validates the choice on save. Derived from +integration_class+ so
        # carrier providers get the right answer by declaring only that.
        #
        # @param store [Spree::Store, nil]
        # @return [Boolean]
        def available_for_store?(store)
          return true if integration_class.blank?

          store.present? && store.integrations.active.exists?(type: integration_class)
        end
      end

      # @param delivery_method [Spree::DeliveryMethod]
      def initialize(delivery_method)
        @delivery_method = delivery_method
      end

      # Quotes this delivery method for a package.
      #
      # Returning nil suppresses the method, matching the calculator contract
      # where a nil cost hides it — that equivalence is what lets FlatRate's
      # thresholds keep working through the Internal provider.
      #
      # @param _package [Spree::Stock::Package]
      # @return [Spree::DeliveryRateProvider::Estimate, nil]
      def estimate(_package)
        raise NotImplementedError, "Please implement 'estimate' in your delivery rate provider: #{self.class.name}"
      end

      # Reserves the quote with the carrier once a customer selects it.
      # Spree does not invoke this yet — it is reserved for the rate booking
      # flow; until then a provider gem calls it from its own fulfillment
      # provider.
      def book(_delivery_rate); end

      # Releases a previously booked quote. Same status as {#book}.
      def release(_delivery_rate); end

      private

      def store
        delivery_method.store
      end

      # The connected, active integration carrying this provider's credentials.
      # Memoizes the missing case too — an unconnected integration must not
      # cost a query per estimate.
      #
      # @return [Spree::Integration, nil]
      def integration
        return if self.class.integration_class.blank?
        return @integration if defined?(@integration)

        @integration = store&.integrations&.active&.find_by(type: self.class.integration_class)
      end
    end
  end
end
