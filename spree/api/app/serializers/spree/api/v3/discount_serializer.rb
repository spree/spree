module Spree
  module Api
    module V3
      # Unified discount serializer for applied promotions on Cart and Order.
      # Replaces CartPromotionSerializer and OrderPromotionSerializer.
      class DiscountSerializer < BaseSerializer
        typelize name: :string, description: [:string, nullable: true], code: [:string, nullable: true],
                 amount: [:string, nullable: true], display_amount: [:string, nullable: true], promotion_id: :string

        attribute :promotion_id do |record|
          record.promotion&.prefixed_id
        end

        attributes :name, :description, :code

        # Nulled for gated (prices_hidden) guests so an applied discount can't
        # leak the amount the cart/order totals already withhold.
        money_attributes :amount, :display_amount
      end
    end
  end
end
