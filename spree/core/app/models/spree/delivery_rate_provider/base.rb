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

        # Fulfillment types this provider can quote, so admin UIs narrow the
        # type field once a provider is chosen. An empty list means "any
        # type" — the Internal (calculator) provider prices anything.
        #
        # @return [Array<String>]
        def fulfillment_types
          []
        end

        # Whether the method's calculator decides the price. False for
        # carrier providers, which quote live rates — their methods still
        # carry a calculator (the Estimator consults `available?`) but its
        # amount is never used, so admin UIs hide the pricing form.
        #
        # @return [Boolean]
        def uses_calculator?
          false
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

        # The carrier services this provider can quote, for the admin service
        # picker. An empty list means the provider exposes no catalog and
        # every returned rate is offered. Providers with a stable service set
        # return `[{ carrier:, service:, label: }]`.
        #
        # @param _integration [Spree::Integration, nil]
        # @return [Array<Hash>]
        def service_catalog(_integration)
          []
        end
      end

      # @param delivery_method [Spree::DeliveryMethod]
      def initialize(delivery_method)
        @delivery_method = delivery_method
      end

      # Every quote this delivery method yields for a package — the entry
      # point the Estimator calls. Carrier providers override this to return
      # one Estimate per service ("UPS Ground", "UPS Express", …) from a
      # single API call; single-quote providers implement {#estimate} and get
      # wrapped automatically. An empty array offers nothing.
      #
      # @param package [Spree::Stock::Package]
      # @return [Array<Spree::DeliveryRateProvider::Estimate>]
      def estimates(package)
        Array(estimate(package)).compact
      end

      # Quotes this delivery method for a package, for providers that yield a
      # single rate.
      #
      # Returning nil suppresses the method, matching the calculator contract
      # where a nil cost hides it — that equivalence is what lets FlatRate's
      # thresholds keep working through the Internal provider.
      #
      # @param _package [Spree::Stock::Package]
      # @return [Spree::DeliveryRateProvider::Estimate, nil]
      def estimate(_package)
        raise NotImplementedError, "Please implement 'estimate' or 'estimates' in your delivery rate provider: #{self.class.name}"
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
