module Spree
  # Thread-safe, per-request attributes for the current store context.
  #
  # All attributes are automatically reset between requests by Rails.
  # Fallback chains ensure sensible defaults when attributes are not explicitly set.
  class Current < ::ActiveSupport::CurrentAttributes
    attribute :store, :market, :currency, :locale, :zone, :default_tax_zone, :price_lists, :global_pricing_context

    resets { @default_tax_zone_loaded = false }

    # Returns the current store, falling back to the default store.
    # @return [Spree::Store]
    def store
      super || Spree::Store.default
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
    # Fallback: market default locale -> store default locale.
    # @return [String] locale code, e.g. +"en"+, +"de"+
    def locale
      super || market&.default_locale || store&.default_locale
    end

    # Returns the current tax zone, falling back to the default tax zone.
    # @return [Spree::Zone, nil]
    def zone
      super || default_tax_zone
    end

    # Returns the default tax zone (memoized per request).
    # @return [Spree::Zone, nil]
    def default_tax_zone
      result = super
      return result if result || @default_tax_zone_loaded

      @default_tax_zone_loaded = true
      self.default_tax_zone = Spree::Zone.find_by(default_tax: true)
    end

    # Returns the current price lists for the global pricing context.
    # @return [ActiveRecord::Relation<Spree::PriceList>]
    def price_lists
      super || begin
        context = global_pricing_context
        self.price_lists = Spree::PriceList.for_context(context)
      end
    end

    # Returns the current global pricing context, built from store, currency, zone, and market.
    # @return [Spree::Pricing::Context]
    def global_pricing_context
      super || begin
        self.global_pricing_context = Spree::Pricing::Context.new(
          currency: currency,
          store: store,
          zone: zone,
          market: market
        )
      end
    end
  end
end
