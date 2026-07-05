module Spree
  module Api
    module V3
      module Admin
        class AdjustmentSerializer < V3::BaseSerializer
          typelize label: :string, amount: :string, display_amount: :string,
                   included: :boolean,
                   order_id: [:string, nullable: true]

          attributes :label, :display_amount, :included,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :amount do |adjustment|
            adjustment.amount.to_s
          end

          attribute :order_id do |adjustment|
            adjustment.order&.prefixed_id
          end
        end
      end
    end
  end
end
