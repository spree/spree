module Spree
  # Thread-safe, per-request attributes for the current store context.
  #
  # All attributes are automatically reset between requests by Rails.
  # Fallback chains ensure sensible defaults when attributes are not explicitly set.
  class Current < ::ActiveSupport::CurrentAttributes
    attribute :store, :channel, :market, :currency, :locale, :content_locale, :tax_country, :price_lists, :applicable_catalogs, :quantity_rules_resolvers, :standing_companies, :global_pricing_context, :provider_cache, :integrations

    # Scratch space for provider strategies to memoize a call across the
    # request — part of the delivery rate provider contract (nothing in core
    # writes to it): a carrier gem keys its quote here so several delivery
    # methods sharing one carrier cost a single API round-trip rather than
    # one each. Keys must be namespaced by the provider (see the custom
    # delivery rate provider guide).
    # @return [Hash]
    def provider_cache
      super || (self.provider_cache = {})
    end

    # Returns the current store, falling back to the default store.
    # @return [Spree::Store]
    def store
      super || Spree::Store.default
    end

    def channel
      super || (self.channel = store&.default_channel)
    end

    # Returns the current market, falling back to the store's default market.
    # @return [Spree::Market, nil]
    def market
      super || store&.default_market
    end

    # Returns the current currency.
    # Fallback: market currency -> store default currency.
    # @return [String] currency ISO code, e.g. +"USD"+
    def currency
      super || market&.currency || store&.default_currency
    end

    # Returns the current locale.
    # Fallback: market default locale -> store default locale -> I18n default.
    # @return [String] locale code, e.g. +"en"+, +"de"+
    def locale
      super || market&.default_locale.presence || store&.default_locale.presence || I18n.default_locale.to_s
    end

    # Returns the locale that base (untranslated) record columns are authored
    # in for the current request — the current store's default locale. It is
    # assigned per request alongside +I18n.locale+ and must never be written
    # to the process-global +I18n.default_locale+, which every thread in the
    # server process shares. Outside a request it falls back to the
    # application default locale.
    # @return [String] locale code, e.g. +"en"+, +"de"+
    def content_locale
      super.presence || I18n.default_locale.name
    end

    # The country whose tax applies while browsing, before any address exists.
    # Fallback: the market being browsed -> the store's own country. An order
    # in hand answers this better (Spree::Purchase::Taxation#tax_country reads
    # its address first); this is the storefront's answer without one.
    #
    # Assigns the resolved country the way #channel does, because the fallback
    # costs a query: a product listing builds one pricing context per variant,
    # and each would otherwise re-ask the market for its default country.
    # @return [Spree::Country, nil]
    def tax_country
      super || (self.tax_country = market&.default_country || store&.default_country)
    end

    # The current store's active integrations, loaded once per request.
    # Lazy — a request that never asks pays nothing — and assigned on first
    # read the way #tax_country is, because several consumers ask per request:
    # every integration-backed provider resolving credentials, and the
    # settings page checking availability across the whole registry.
    # @return [Array<Spree::Integration>]
    def integrations
      super || (self.integrations = store ? store.integrations.active.to_a : [])
    end

    # Returns the standalone (rule-matched) price lists in effect for the
    # global pricing context. Catalog-owned lists are excluded — pricing
    # reaches them through {#catalogs_for}.
    # @return [ActiveRecord::Relation<Spree::PriceList>]
    def price_lists
      super || begin
        context = global_pricing_context
        self.price_lists = Spree::PriceList.for_context(context)
      end
    end

    # Catalogs that apply to a buyer in this request, keyed by that buyer.
    # A store can have many catalogs; only the company / customer-group /
    # channel-default set is kept. Product listings price every variant
    # through a new resolver, so the first call loads the set and the rest
    # reuse it.
    #
    # @param company [Spree::Company, nil]
    # @param user [Object, nil]
    # @param channel [Spree::Channel, nil]
    # @return [Array<Spree::Catalog>]
    def catalogs_for(company: nil, user: nil, channel: nil)
      channel ||= self.channel
      key = [store&.id, company&.id, user&.id, channel&.id]
      applicable_catalogs[key] ||= Spree::Catalog.for_context(
        store: store, company: company, user: user, channel: channel
      )
    end

    # @return [Hash]
    def applicable_catalogs
      super || (self.applicable_catalogs = {})
    end

    # The quantity-rule resolver for a buyer in this request, keyed the same
    # way their catalogs are.
    #
    # Request-scoped rather than per-caller because a serializer is built
    # fresh for every variant on a listing: a per-instance memo would reload
    # and re-hash each catalog's override rows once per row on the page.
    #
    # @param company [Spree::Company, nil]
    # @param user [Object, nil]
    # @param channel [Spree::Channel, nil]
    # @return [Spree::Catalogs::ResolveQuantityRules]
    def quantity_rules_resolver_for(company: nil, user: nil, channel: nil)
      channel ||= self.channel
      key = [store&.id, company&.id, user&.id, channel&.id]
      quantity_rules_resolvers[key] ||= Spree::Catalogs::ResolveQuantityRules.new(
        catalogs_for(company: company, user: user, channel: channel)
      )
    end

    # @return [Hash]
    def quantity_rules_resolvers
      super || (self.quantity_rules_resolvers = {})
    end

    # The company a customer unambiguously buys for in this request. Resolved
    # once: catalog resolution asks for it on every entry, and a product
    # listing prices every variant through that path — unmemoized it was two
    # queries per row.
    #
    # @param customer [Object, nil]
    # @return [Spree::Company, nil]
    def standing_company_for(customer)
      return nil if store.nil? || customer.nil?

      key = [store.id, customer.id]
      return standing_companies[key] if standing_companies.key?(key)

      standing_companies[key] = Spree::Company.sole_standing_for(store: store, customer: customer)
    end

    # @return [Hash]
    def standing_companies
      super || (self.standing_companies = {})
    end

    # Drops everything derived from the catalog set, so a write in this
    # request is not read back through a memo it has already superseded.
    # One call rather than a list every caller has to keep in step.
    # @return [void]
    def reset_catalog_memos
      self.applicable_catalogs = nil
      self.quantity_rules_resolvers = nil
      self.standing_companies = nil
      self.price_lists = nil
    end

    # Returns the current global pricing context, built from store, currency, country, and market.
    # @return [Spree::Pricing::Context]
    def global_pricing_context
      super || begin
        self.global_pricing_context = Spree::Pricing::Context.new(
          currency: currency,
          store: store,
          country: tax_country,
          market: market,
          channel: channel
        )
      end
    end
  end
end
