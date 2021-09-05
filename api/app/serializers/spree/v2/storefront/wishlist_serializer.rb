module Spree
  module V2
    module Storefront
      class WishlistSerializer < BaseSerializer
        set_type :wishlist

        attributes :token, :name, :is_private, :is_default

        belongs_to :user
        has_many :wished_products
      end
    end
  end
end
