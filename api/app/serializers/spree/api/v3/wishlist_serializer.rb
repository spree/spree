module Spree
  module Api
    module V3
      class WishlistSerializer < BaseSerializer
        attributes :id, :name, :token, created_at: :iso8601, updated_at: :iso8601

        attribute :is_default do |wishlist|
          wishlist.is_default?
        end

        attribute :is_private do |wishlist|
          wishlist.is_private?
        end

        many :items,
             key: :items,
             resource: Spree.api.v3_storefront_wished_item_serializer,
             if: proc { params[:includes]&.include?('items') } do |wishlist|
          wishlist.wished_items
        end
      end
    end
  end
end
