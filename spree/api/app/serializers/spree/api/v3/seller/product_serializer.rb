module Spree
  module Api
    module V3
      module Seller
        # A seller's own product.
        #
        # Read and write have to name the same fields: the panel loads a
        # product into a form and sends it back, so anything the controller
        # accepts but this withholds would be blanked on save. The reverse
        # matters too — how a product is filed (type, categories, collections,
        # tags) is the marketplace's own merchandising, so it is neither
        # written nor read here.
        class ProductSerializer < V3::ProductSerializer
          typelize status: :string, metadata: 'Record<string, unknown>'

          attributes :status, :metadata, created_at: :iso8601, updated_at: :iso8601

          many :variants,
               resource: proc { Spree.api.seller_variant_serializer },
               if: proc { expand?('variants') }

          one :default_variant,
              resource: proc { Spree.api.seller_variant_serializer },
              if: proc { expand?('default_variant') }

          many :gallery_media,
               key: :media,
               resource: proc { Spree.api.seller_media_serializer },
               if: proc { expand?('media') }

          many :option_types,
               resource: proc { Spree.api.option_type_serializer },
               if: proc { expand?('option_types') }
        end
      end
    end
  end
end
