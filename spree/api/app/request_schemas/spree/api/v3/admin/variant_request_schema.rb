module Spree
  module Api
    module V3
      module Admin
        # The shared variant attributes, plus the marketplace configuration
        # only an operator sets.
        class VariantRequestSchema < Spree::Api::V3::VariantRequestSchema
          publishes 'VariantParams'

          attribute :seller_id, :id
          attribute :delivery_profile_id, :id, nullable: true
          attribute :tax_category_id, :id
          attribute :prices, :array, of: Spree::Api::V3::PriceRequestSchema,
            description: 'Per-currency prices. Upserted by currency.'
          attribute :stock_levels, :array, of: Spree::Api::V3::StockLevelRequestSchema,
            description: 'Stock per location. Upserted by location; omitted locations are removed.'
        end
      end
    end
  end
end
