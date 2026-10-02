# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ClaimSerializer < V3::ClaimSerializer
          typelize memo: [:string, nullable: true],
                   metadata: 'Record<string, unknown>',
                   created_by_id: [:string, nullable: true],
                   created_by_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind']

          attributes :memo, :metadata, created_at: :iso8601, updated_at: :iso8601

          actor_attributes :created_by

          expandable :many, :claim_line_items, :admin_claim_line_item_serializer

          expandable :one, :reason, :admin_claim_reason_serializer
          expandable :one, :order, :admin_order_serializer
          expandable :many, :refunds, :admin_refund_serializer
        end
      end
    end
  end
end
