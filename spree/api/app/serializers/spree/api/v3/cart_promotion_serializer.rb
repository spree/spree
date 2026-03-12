module Spree
  module Api
    module V3
      # Cart-facing promotion serializer.
      # Same data as OrderPromotionSerializer but IDs use the cp_ prefix.
      class CartPromotionSerializer < BaseSerializer
        typelize name: :string, description: [:string, nullable: true], code: [:string, nullable: true],
                 amount: :string, display_amount: :string, promotion_id: :string

        attribute :promotion_id do |cart_promotion|
          cart_promotion.promotion&.prefixed_id
        end

        attributes :name, :description, :code, :amount, :display_amount
      end
    end
  end
end
