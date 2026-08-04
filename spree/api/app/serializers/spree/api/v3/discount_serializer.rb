module Spree
  module Api
    module V3
      # A typed Spree::Discount money row (promotion-sourced or manual) on a
      # line item or fulfillment. The embedded `discounts` key on Cart/Order
      # stays the applied-promotion summary — see AppliedPromotionSerializer.
      class DiscountSerializer < BaseSerializer
        typelize label: :string, kind: :string, code: [:string, nullable: true],
                 value: [:string, nullable: true], value_type: [:string, nullable: true],
                 amount: [:string, nullable: true], display_amount: [:string, nullable: true],
                 promotion_id: [:string, nullable: true], line_item_id: [:string, nullable: true],
                 fulfillment_id: [:string, nullable: true]

        attributes :label, :kind, :code, :value_type

        attribute :value do |record|
          record.value&.to_s
        end

        attribute :promotion_id do |record|
          record.promotion&.prefixed_id
        end

        attribute :line_item_id do |record|
          record.line_item&.prefixed_id
        end

        attribute :fulfillment_id do |record|
          record.fulfillment&.prefixed_id
        end

        money_attributes :amount, :display_amount
      end
    end
  end
end
