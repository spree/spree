module Spree
  module Api
    module V3
      module Admin
        class AdjustmentSerializer < V3::BaseSerializer
          typelize label: :string, amount: :string, display_amount: :string,
                   state: :string, eligible: :boolean, mandatory: :boolean, included: :boolean,
                   source_type: [:string, nullable: true],
                   adjustable_type: :string, adjustable_id: :string,
                   order_id: [:string, nullable: true],
                   source_id: [:string, nullable: true]

          attributes :label, :display_amount, :state, :eligible, :mandatory, :included,
                     :source_type, :adjustable_type,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :amount do |adjustment|
            adjustment.amount.to_s
          end

          attribute :adjustable_id do |adjustment|
            adjustment.adjustable&.prefixed_id
          end

          attribute :order_id do |adjustment|
            adjustment.order&.prefixed_id
          end

          attribute :source_id do |adjustment|
            adjustment.source&.prefixed_id
          end
        end
      end
    end
  end
end
