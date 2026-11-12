module Spree
  module Api
    module V3
      module Admin
        # A fixed price a price list sets for one variant, currency and quantity.
        class PriceListPriceRequestSchema < Spree::Api::V3::RequestSchema
          publishes 'PriceListPriceOverrideParams'

          attribute :id, :id,
            description: 'Updates this price row. Without it, the row upserts on `(variant_id, currency, min_quantity)`.'
          attribute :variant_id, :id, example: 'variant_xY9'
          attribute :currency, :currency, example: 'USD'
          attribute :min_quantity, :integer,
            description: "The rung of the variant's ladder. Omit for the bottom rung."
          attribute :amount, :decimal, nullable: true, example: '19.99'
          attribute :compare_at_amount, :decimal, nullable: true, example: '19.99'
        end
      end
    end
  end
end
