# this is actually a serializer for Spree::OrderPromotion, not Spree::Promotion
# we should fix this in the future
module Spree
  module V2
    module Storefront
      class OrderPromotionSerializer < BaseSerializer
        set_id     :promotion_id
        set_type   :promotion

        attributes :name, :description, :amount, :display_amount, :code, :public_metadata
      end
    end
  end
end
