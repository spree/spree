module Spree
  module Api
    module V3
      class WishlistSerializer < BaseSerializer
        typelize name: :string, token: :string, is_default: :boolean, is_private: :boolean

        attributes :name, :token

        attribute :is_default do |wishlist|
          wishlist.is_default?
        end

        attribute :is_private do |wishlist|
          wishlist.is_private?
        end

        many :wished_items,
             key: :items,
             resource: proc { Spree.api.wishlist_item_serializer },
             if: proc { expand?('items') }
      end
    end
  end
end
