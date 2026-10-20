module Spree
  module Api
    module V3
      class WishlistItemSerializer < BaseSerializer
        typelize variant_id: :string, wishlist_id: :string, quantity: :number,
                 product_id: :string

        prefixed_id_attributes :variant, :product, :wishlist

        attributes :quantity

        one :variant, resource: proc { Spree.api.variant_serializer }
        one :product, resource: proc { Spree.api.product_serializer },
            if: proc { expand?('product') }
      end
    end
  end
end
