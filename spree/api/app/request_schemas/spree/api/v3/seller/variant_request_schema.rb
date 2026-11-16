module Spree
  module Api
    module V3
      module Seller
        # The shared variant attributes. Narrower than the operator's set:
        # `seller_id` would let a payload hand a variant to somebody else, and
        # `tax_category_id`/`delivery_profile_id` are marketplace configuration.
        class VariantRequestSchema < Spree::Api::V3::VariantRequestSchema
          publishes 'VariantParams'

          attribute :prices, :array, of: Spree::Api::V3::Seller::PriceRequestSchema,
            description: 'Per-currency prices. Upserted by currency.'
          attribute :stock_levels, :array, of: Spree::Api::V3::StockLevelRequestSchema,
            description: "Stock per location, at this seller's own locations only: a location belonging to anyone else is ignored."
          definition.describe_attribute :options,
                                        'One pair per option type the variant takes part in (size, color), naming an option type and ' \
                                        'value the marketplace already defines (see `GET /option_types`). A seller cannot add to that ' \
                                        'vocabulary, so an unknown name is refused with a 422.'
        end
      end
    end
  end
end
