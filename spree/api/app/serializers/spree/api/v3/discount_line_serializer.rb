module Spree
  module Api
    module V3
      class DiscountLineSerializer < BaseSerializer
        typelize label: :string, amount: :string, display_amount: :string,
                 kind: [:string, nullable: true],
                 promotion_id: [:string, nullable: true]

        attributes :label, :display_amount, :kind

        attribute :amount do |discount_line|
          discount_line.amount.to_s
        end

        attribute :promotion_id do |discount_line|
          discount_line.promotion&.prefixed_id
        end
      end
    end
  end
end
