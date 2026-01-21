module Spree
  module Api
    module V3
      class WishlistSerializer < BaseSerializer
        attributes :id, :name, :token

        attribute :is_default do |wishlist|
          wishlist.is_default?
        end

        attribute :is_private do |wishlist|
          wishlist.is_private?
        end

        many :wished_items,
             key: :items,
             resource: Spree.api.v3_storefront_wished_item_serializer,
             if: proc { params[:includes]&.include?('items') }
      end
    end
  end
end
