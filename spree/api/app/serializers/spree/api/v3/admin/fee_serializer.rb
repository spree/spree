module Spree
  module Api
    module V3
      module Admin
        class FeeSerializer < V3::BaseSerializer
          typelize label: :string, amount: :string, display_amount: :string,
                   kind: :string, order_id: :string,
                   line_item_id: [:string, nullable: true],
                   fulfillment_id: [:string, nullable: true]

          attributes :label, :display_amount, :kind,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :amount do |fee|
            fee.amount.to_s
          end

          attribute :order_id do |fee|
            fee.order&.prefixed_id
          end

          attribute :line_item_id do |fee|
            fee.line_item&.prefixed_id
          end

          attribute :fulfillment_id do |fee|
            fee.fulfillment&.prefixed_id
          end
        end
      end
    end
  end
end
