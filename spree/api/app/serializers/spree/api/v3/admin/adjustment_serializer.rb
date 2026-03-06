module Spree
  module Api
    module V3
      module Admin
        class AdjustmentSerializer < BaseSerializer
          typelize amount: :string, label: [:string, nullable: true],
                   eligible: :boolean, state: :string, mandatory: [:boolean, nullable: true],
                   source_type: [:string, nullable: true],
                   source_id: [:string, nullable: true],
                   adjustable_type: [:string, nullable: true],
                   adjustable_id: [:string, nullable: true],
                   order_id: [:string, nullable: true],
                   included: :boolean

          attributes :amount, :label, :eligible, :state, :included, :mandatory,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :source_type do |adjustment|
            adjustment.source_type
          end

          attribute :source_id do |adjustment|
            adjustment.source&.prefixed_id
          end

          attribute :adjustable_type do |adjustment|
            adjustment.adjustable_type
          end

          attribute :adjustable_id do |adjustment|
            adjustment.adjustable&.prefixed_id
          end

          attribute :order_id do |adjustment|
            adjustment.order&.prefixed_id
          end

          one :order,
              resource: Spree.api.admin_order_serializer,
              if: proc { expand?('order') }
        end
      end
    end
  end
end
