module Spree
  module Api
    module V3
      module Seller
        # The shared variant attributes. Narrower than the operator's set:
        # `seller_id` would let a payload hand a variant to somebody else, and
        # `tax_category_id` is marketplace configuration.
        class VariantRequestSchema < Spree::Api::V3::VariantRequestSchema
          publishes 'VariantParams'

          # Means something only on an offer against a master product, where
          # it names how that seller's row ships; the model blanks it on a
          # variant of a product the seller owns
          # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 10).
          attribute :delivery_profile_id, :id,
            nullable: true,
            description: "Which of the marketplace's delivery profiles this offer ships under. Ignored on a variant of a product the seller owns."

          attribute :prices, :array, of: Spree::Api::V3::Seller::PriceRequestSchema,
            description: 'Per-currency prices. Upserted by currency.'
          attribute :stock_levels, :array, of: Spree::Api::V3::StockLevelRequestSchema,
            description: "Stock per location, at this seller's own locations only: a location belonging to anyone else is ignored."
        end
      end
    end
  end
end
