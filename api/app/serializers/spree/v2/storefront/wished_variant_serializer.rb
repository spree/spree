module Spree
  module V2
    module Storefront
      class WishedVariantSerializer < BaseSerializer
        set_type :wished_variant

        attributes :quantity

        attribute :price do |wished_variant, params|
          wished_variant.price(currency: params[:currency])
        end

        attribute :total do |wished_variant, params|
          wished_variant.total(currency: params[:currency])
        end

        attribute :display_price do |wished_variant, params|
          wished_variant.display_price(currency: params[:currency])
        end

        attribute :display_total do |wished_variant, params|
          wished_variant.display_total(currency: params[:currency])
        end

        belongs_to :variant
        belongs_to :wishlist, serializer: ::Spree::V2::Storefront::WishlistSerializer
      end
    end
  end
end
