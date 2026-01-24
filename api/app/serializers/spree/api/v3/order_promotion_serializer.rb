module Spree
  module Api
    module V3
      class OrderPromotionSerializer < BaseSerializer
        typelize name: :string, description: 'string | null', code: 'string | null',
                 amount: :number, display_amount: :string, promotion_id: :string

        attribute :promotion_id do |order_promotion|
          order_promotion.promotion&.prefix_id
        end

        attributes :name, :description, :code, :amount, :display_amount
      end
    end
  end
end
