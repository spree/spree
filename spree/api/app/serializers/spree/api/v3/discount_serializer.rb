module Spree
  module Api
    module V3
      # A typed Spree::Discount money row (promotion-sourced or manual) on a
      # line item or fulfillment. The embedded `discounts` key on Cart/Order
      # stays the applied-promotion summary — see AppliedPromotionSerializer.
      class DiscountSerializer < BaseSerializer
        typelize label: :string, kind: [:string, enum: Spree::Discount::KINDS], code: [:string, nullable: true],
                 value: [:string, nullable: true], value_type: [:string, nullable: true],
                 promotion_id: [:string, nullable: true], line_item_id: [:string, nullable: true],
                 fulfillment_id: [:string, nullable: true]

        attributes :label, :kind, :code, :value_type

        # A percent discount carries a rate; a flat one an amount.
        attribute :value do |record|
          next Spree::Money::Rounding.format_decimal(record.value) if record.value_type == 'percent'

          Spree::Money::Rounding.format(record.value, record.currency) unless params[:hide_prices]
        end

        prefixed_id_attributes :promotion, :line_item, :fulfillment

        money_attributes :amount, :display_amount
      end
    end
  end
end
