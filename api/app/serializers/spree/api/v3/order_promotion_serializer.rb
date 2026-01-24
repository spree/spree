module Spree
  module Api
    module V3
      class OrderPromotionSerializer < BaseSerializer
        typelize_from Spree::OrderPromotion

        attributes :id, :name, :description, :code, :amount, :display_amount, :promotion_id
      end
    end
  end
end
