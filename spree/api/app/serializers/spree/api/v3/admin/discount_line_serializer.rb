module Spree
  module Api
    module V3
      module Admin
        class DiscountLineSerializer < V3::DiscountLineSerializer
          typelize order_id: :string,
                   promotion_action_id: [:string, nullable: true],
                   line_item_id: [:string, nullable: true],
                   fulfillment_id: [:string, nullable: true]

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :order_id do |discount_line|
            discount_line.order&.prefixed_id
          end

          attribute :promotion_action_id do |discount_line|
            discount_line.promotion_action&.prefixed_id
          end

          attribute :line_item_id do |discount_line|
            discount_line.line_item&.prefixed_id
          end

          attribute :fulfillment_id do |discount_line|
            discount_line.fulfillment&.prefixed_id
          end
        end
      end
    end
  end
end
