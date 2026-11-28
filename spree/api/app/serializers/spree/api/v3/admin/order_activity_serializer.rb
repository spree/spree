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

          # What identifies a payment or a refund, as opposed to its amount,
          # which the order shows anyone who can read it.
          PAYMENT_DETAILS = %w[payment_id payment_method brand last4 transaction_id].freeze
          REFUND_DETAILS = %w[refund_id reason transaction_id].freeze

          attributes :kind, :category, :body, created_at: :iso8601

          attribute :details do |activity|
            hidden = []
            hidden += PAYMENT_DETAILS unless params[:payment_records]
            hidden += REFUND_DETAILS unless params[:refund_records]
            activity.details&.except(*hidden)
          end

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
