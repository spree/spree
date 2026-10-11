module Spree
  module Api
    module V3
      module Admin
        # A fixed price a price list sets for one variant, currency and quantity.
        class PriceListPriceRequestSchema < Spree::Api::V3::RequestSchema
          publishes 'PriceListPriceOverrideParams'

          id :id, description: 'Updates this price row. Without it, the row upserts on `(variant_id, currency, min_quantity)`.'
          id :variant_id, example: 'variant_xY9'
          string :currency, example: 'USD'
          integer :min_quantity, description: "The rung of the variant's ladder. Omit for the bottom rung."
          decimal :amount, :compare_at_amount, nullable: true, example: '19.99'
        end
      end
    end
  end
end
