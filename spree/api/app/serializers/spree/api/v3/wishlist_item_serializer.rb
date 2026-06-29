module Spree
  module Api
    module V3
      class WishlistItemSerializer < BaseSerializer
        typelize variant_id: :string, wishlist_id: :string, quantity: :number

        attribute :variant_id do |wished_item|
          wished_item.variant&.prefixed_id
        end

        attribute :wishlist_id do |wished_item|
          wished_item.wishlist&.prefixed_id
        end

        attributes :quantity

        one :variant, resource: proc { Spree.api.variant_serializer }
      end
    end
  end
end
