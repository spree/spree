module Spree
  class Current < ::ActiveSupport::CurrentAttributes
    attribute :store, :market, :currency, :zone, :price_lists, :global_pricing_context

    def store
      super || Spree::Store.default
    end

    def market
      super || store&.default_market
    end

    def currency
      super || market&.currency || store&.default_currency
    end

    def zone
      super || Spree::Zone.default_tax || store&.checkout_zone
    end

    def price_lists
      super || begin
        context = global_pricing_context
        self.price_lists = Spree::PriceList.for_context(context)
      end
    end

    def global_pricing_context
      super || begin
        self.global_pricing_context = Spree::Pricing::Context.new(
          currency: currency,
          store: store,
          zone: zone
        )
      end
    end
  end
end
