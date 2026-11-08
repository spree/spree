module Spree
  module Api
    module V3
      module Seller
        # The operator's price shape, except `currency` may be left out: the
        # store's currency is assumed (see `default_price_currencies`).
        class PriceRequestSchema < Spree::Api::V3::RequestSchema
          attribute :currency, :currency,
            example: 'USD',
            description: "Omit to price in the store's currency. A seller has no currency of their own."
          attribute :amount, :decimal,
            required: true,
            example: '24.00',
            description: 'A canonical decimal string (`"1234.56"`: period decimal, no grouping). The API does not parse localized input.'
          attribute :compare_at_amount, :decimal, nullable: true, example: '30.00'
        end
      end
    end
  end
end
