module Spree
  module Pricing
    # Picks the engine that answers a price, and stands between it and the rest
    # of Spree.
    #
    # This sits on the catalog read path — the Store API serializers price every
    # row of every listing — so three things happen here rather than in each
    # provider:
    #
    # * a provider that declines the context (+handles?+) never gets asked, so
    #   anonymous browsing stays on the local catalog even when a contract
    #   pricing system is connected;
    # * an answer is cached for providers that declare a +cache_ttl+, keyed by
    #   the context;
    # * a provider that raises is handled per the store's failure policy —
    #   +strict+ re-raises as {ProviderUnavailable} so the caller decides,
    #   +fallback+ quietly uses Spree's own price.
    class PriceResolution
      # Raised when the configured provider could not answer and the store's
      # policy is to refuse rather than substitute a catalog price. Callers in
      # a checkout flow turn this into a retryable failure; the catalog read
      # path treats it as "no price".
      class ProviderUnavailable < StandardError
        attr_reader :provider_key

        def initialize(message = nil, provider_key: nil)
          @provider_key = provider_key
          super(message)
        end
      end

      # @param context [Spree::Pricing::Context]
      # @return [Spree::Price, nil]
      def self.call(context)
        new(context).resolve
      end

      attr_reader :context

      def initialize(context)
        @context = context
      end

      # @return [Spree::Price, nil]
      def resolve
        return internal_price unless external_provider?

        provider_price
      rescue ProviderUnavailable
        raise
      rescue StandardError => e
        handle_failure(e)
      end

      private

      def store
        context.store
      end

      def provider
        @provider ||= store&.pricing_provider_instance || Spree::PricingProvider::Internal.new
      end

      # Internal is not "an external system that happens to be local": skipping
      # the cache and the rescue for it keeps the default path exactly as it
      # was before providers existed.
      def external_provider?
        !provider.is_a?(Spree::PricingProvider::Internal) && provider.handles?(context)
      end

      def provider_price
        ttl = provider.cache_ttl
        return stamp(provider.price_for(context)) if ttl.blank?

        cached = Rails.cache.fetch(provider_cache_key(store_id: store&.id), expires_in: ttl) do
          price = provider.price_for(context)
          price&.attributes
        end

        return if cached.blank?

        stamp(build_price(cached))
      end

      # An internal answer carries no source: NULL on the line item means
      # "Spree's own catalog", where price_list_id already says which list.
      def internal_price
        Spree::PricingProvider::Internal.new.price_for(context)
      end

      # A cached price is rebuilt from attributes rather than stored as an
      # object: a marshalled Active Record instance carries the schema it was
      # dumped under, and comes back broken after a migration.
      def build_price(attributes)
        Spree::Price.new(attributes.except('id')).tap do |price|
          price.variant ||= context.variant
        end
      end

      # An external price must never be saved into the catalog — readonly! is
      # what turns "someone called save" from silent corruption into an error.
      # It also carries which provider answered, so the line item can record
      # that rather than whatever the store happens to be configured for.
      def stamp(price)
        return if price.blank?

        # The context always knows the variant, and the tax-inclusive
        # restatement reads it — a provider that builds a Price without one
        # would otherwise fail deep in that call with an obscure NoMethodError
        # rather than anywhere near the provider that omitted it.
        price.variant ||= context.variant
        price.readonly!
        price.price_source = provider.class.key
        price
      end

      # The store id is passed in rather than read here so the key visibly
      # carries it — core's cache-key audit reads the call site, and a reader
      # should not have to follow Pricing::Context to satisfy themselves that
      # two stores cannot share an entry.
      #
      # Deliberately not Context#cache_key: that includes the context's date
      # to the second, which would make every entry unique and the TTL
      # meaningless. Staleness is bounded by the provider's cache_ttl instead.
      def provider_cache_key(store_id:)
        [
          'spree', 'pricing_provider', provider.class.key, store_id,
          context.variant&.id, context.currency, context.country_code,
          context.market&.id, context.channel&.id, context.user&.id, context.quantity
        ].join('/')
      end

      # Strict refuses to *charge* an unconfirmed price — it must not take the
      # catalog down. A checkout context carries the order and gets the
      # exception, so the workflow can fail the step; a catalog read (no
      # order) gets nil, which the serializers already render as "no price".
      def handle_failure(error)
        policy = store&.pricing_failure_policy
        Spree::ProviderFailurePolicy.report_fallback(
          kind: 'pricing', provider: provider.class.key, store: store, error: error,
          policy: policy || Spree::ProviderFailurePolicy::DEFAULT_PRICING_POLICY
        )

        return internal_price unless policy == 'strict'
        return nil if context.order.blank?

        raise ProviderUnavailable.new(error.message, provider_key: provider.class.key)
      end
    end
  end
end
