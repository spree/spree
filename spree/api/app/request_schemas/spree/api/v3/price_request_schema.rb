module Spree
  module Api
    module V3
      # A variant's price in one currency.
      class PriceRequestSchema < Spree::Api::V3::RequestSchema
        publishes 'PriceParams'

        attribute :currency, :currency, required: true, example: 'USD'
        attribute :amount, :decimal,
          required: true,
          example: '29.99',
          description: 'A canonical decimal string (`"1234.56"`: period decimal, no grouping). The API does not parse localized input.'
        attribute :compare_at_amount, :decimal, nullable: true, example: '39.99'
      end
    end
  end
end
