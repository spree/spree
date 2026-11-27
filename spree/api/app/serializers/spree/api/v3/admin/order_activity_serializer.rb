module Spree
  module Api
    module V3
      module Admin
        class OrderActivitySerializer < V3::BaseSerializer
          typelize kind: [:string, comment: 'The event that recorded the entry (`payment.completed`), or `comment`.'],
                   category: [:string, comment: 'What the timeline groups it under: order, payments, fulfillment, changes, returns, comments.'],
                   body: [:string, nullable: true, comment: 'The comment, for a `comment` entry.'],
                   details: ['Record<string, unknown>', nullable: true, comment: 'What the entry shows. Its keys depend on the kind.'],
                   order_change_id: [:string, nullable: true],
                   actor_id: [:string, nullable: true],
                   actor_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind']

          attributes :kind, :category, :body, :details, created_at: :iso8601

          attribute :order_change_id do |activity|
            Spree::OrderChange.prefixed_id_for(activity.order_change_id)
          end

          actor_attributes :actor

          one :order_change, resource: proc { Spree.api.admin_order_change_serializer }, if: proc { expand?('order_change') }
        end
      end
    end
  end
end
