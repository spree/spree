module Spree
  module PricingProvider
    # Contract for pricing engines — what answers "what does this variant cost
    # for this shopper, right now".
    #
    # A provider returns a {Spree::Price}: {Internal} returns the persisted
    # catalog row, an external provider an **unsaved, readonly** instance. The
    # Active Record shape is deliberately the contract, so everything
    # downstream — tax-inclusive restatement, +discounted?+, the serializers —
    # keeps working without knowing where the number came from. +readonly!+ is
    # what stops an external answer being written back into the catalog.
    #
    # Providers are stateless and constructed without arguments; everything
    # request-specific arrives in the {Spree::Pricing::Context}.
    #
    # **This runs on the catalog read path.** The Store API serializers price
    # every row of every listing, so a provider that calls out to a remote
    # system must declare a +cache_ttl+ and use +handles?+ to send traffic it
    # has no special answer for straight to the internal resolver. A provider
    # that does neither will make an ERP call per product tile.
    class Base
      include Spree::IntegrationBackedProvider

      # @param context [Spree::Pricing::Context]
      # @return [Spree::Price, nil] nil when this provider has no price
      def price_for(_context)
        raise NotImplementedError, "#{self.class} must implement #price_for"
      end

      # Whether this provider wants to answer for this context at all. Return
      # false and the internal resolver answers instead — the escape hatch that
      # keeps anonymous catalog browsing off a contract-pricing system.
      #
      # @param context [Spree::Pricing::Context]
      # @return [Boolean]
      def handles?(_context)
        true
      end

      # How long an answer may be cached, keyed by the context. nil means no
      # caching, which is only correct for a provider reading the local
      # database.
      #
      # @return [ActiveSupport::Duration, Integer, nil]
      def cache_ttl
        nil
      end

    end
  end
end
