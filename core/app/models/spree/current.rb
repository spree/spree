module Spree
  class Current < ::ActiveSupport::CurrentAttributes
    attribute :store, :currency, :zone, :price_lists, :global_pricing_context

    def store
      super || Spree::Store.default
    end

    def currency
      super || store&.default_currency
    end

    def zone
      super || Spree::Zone.default_tax || store&.checkout_zone
    end

    def price_lists
      @price_lists ||= super || Spree::PriceList.for_context(global_pricing_context)
    end

    def global_pricing_context
      @global_pricing_context ||= Spree::Pricing::Context.new(
        currency: currency,
        store: store,
        zone: zone
      )
    end
  end
end
