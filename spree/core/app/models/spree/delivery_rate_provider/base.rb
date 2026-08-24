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
      include Spree::IntegrationBackedProvider

      attr_reader :delivery_method

      class << self
        # Whether this provider quotes real shipments to an address — true
        # for carriers, which therefore can only price methods whose
        # fulfillment provider ships. The Internal (calculator) provider
        # prices anything.
        #
        # @return [Boolean]
        def requires_address?
          false
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

        # The carrier services this store can offer, for the admin service
        # picker. Fetch them live from the carrier wherever the API allows —
        # a hardcoded list shows services the merchant has not enabled and
        # hides the ones they have.
        #
        # Return {ServiceCatalog.listing} with `[{ carrier:, service:,
        # label: }]`, {ServiceCatalog.unavailable} with the seller's message
        # when the listing cannot be fetched (unconnected integration,
        # credential tier without access, carrier outage), or
        # {ServiceCatalog.none} — the default — when the provider lists no
        # services and the merchant types identifiers free-form.
        #
        # Never raise: the picker degrades to free-form entry, and a failed
        # listing must not block configuring a delivery method.
        #
        # @param _integration [Spree::Integration, nil]
        # @return [Spree::DeliveryRateProvider::ServiceCatalog]
        def service_catalog(_integration)
          ServiceCatalog.none
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
