module Spree
  module Api
    module V3
      module Seller
        # A product type as a seller sees it: its name and the custom fields it
        # asks them to fill in.
        #
        # No `products_count` and no option-type or category template — those
        # describe how the operator maintains the type, which is not a seller's
        # concern.
        class ProductTypeSerializer < V3::ProductTypeSerializer
          many :product_type_custom_field_definitions,
               key: :custom_field_definitions,
               resource: proc { Spree.api.seller_product_type_custom_field_definition_serializer }
        end
      end
    end
  end
end
