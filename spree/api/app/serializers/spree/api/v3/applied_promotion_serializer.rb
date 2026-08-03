module Spree
  module Api
    module V3
      # Summary of promotions applied to a Cart or Order (serves the embedded
      # `discounts` key). Distinct from DiscountSerializer, which serializes
      # the typed Spree::Discount money rows.
      class AppliedPromotionSerializer < BaseSerializer
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
