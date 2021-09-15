module Spree
  module V2
    module Storefront
      class WishlistSerializer < BaseSerializer
        set_type :wishlist

        attributes :token, :name, :is_private, :is_default

        has_many :wished_variants
      end
    end
  end
end
