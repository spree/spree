# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ExchangeSerializer < V3::ExchangeSerializer
          typelize memo: [:string, nullable: true],
                   metadata: 'Record<string, unknown>',
                   stock_location_id: [:string, nullable: true],
                   created_by_id: [:string, nullable: true],
                   created_by_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind']

          attributes :memo, :metadata, created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :stock_location

          actor_attributes :created_by

          expandable :many, :exchange_line_items, :admin_exchange_line_item_serializer

          expandable :one, :reason, :admin_return_reason_serializer
          expandable :one, :order, :admin_order_serializer
          expandable :one, :stock_location, :admin_stock_location_serializer
          expandable :many, :refunds, :admin_refund_serializer
        end
      end
    end
  end
end
