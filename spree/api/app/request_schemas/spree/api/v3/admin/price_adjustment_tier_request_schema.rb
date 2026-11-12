module Spree
  module Api
    module V3
      module Admin
        # One quantity tier of a price list's percentage adjustment.
        class PriceAdjustmentTierRequestSchema < Spree::Api::V3::RequestSchema
          publishes 'PriceAdjustmentTierParams'

          attribute :min_quantity, :integer,
            required: true,
            example: 10,
            description: "Above 1; quantity 1 is the list's own `price_adjustment_percentage`."
          attribute :percentage, :decimal,
            required: true,
            example: '-10.0',
            description: 'Signed: negative discounts, positive marks up.'
        end
      end
    end
  end
end
