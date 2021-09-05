module Spree
  module V2
    module Storefront
      class WishedProductSerializer < BaseSerializer
        set_type :wished_product

        attributes :remark, :quantity, :total, :display_total

        belongs_to :variant
        belongs_to :wishlist, serializer: ::Spree::V2::Storefront::WishlistSerializer
      end
    end
  end
end
