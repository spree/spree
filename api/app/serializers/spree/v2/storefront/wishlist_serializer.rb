module Spree
  module V2
    module Storefront
      class WishlistSerializer < BaseSerializer
        set_type :wishlist

        attributes :token, :name, :is_private, :is_default

        attribute :variant_included do |wishlist, params|
          wishlist.include?(params[:is_variant_included])
        end

        has_many :wished_items, serializer: Spree::Api::Dependencies.storefront_wished_item_serializer.constantize
      end
    end
  end
end
