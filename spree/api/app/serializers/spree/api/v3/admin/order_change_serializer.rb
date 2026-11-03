module Spree
  module Api
    module V3
      module Admin
        # A set of changes to a placed order — an admin edit, or the restock
        # or replacement shipment a return, exchange or claim carried out.
        # Admin-only: it is the merchant's audit record, never shown to the
        # customer.
        class OrderChangeSerializer < V3::BaseSerializer
          typelize status: [:string, enum: Spree::OrderChange.statuses, enum_type_name: 'OrderChangeStatus'],
                   order_id: :string,
                   return_id: [:string, nullable: true],
                   exchange_id: [:string, nullable: true],
                   claim_id: [:string, nullable: true],
                   requested_by_id: [:string, nullable: true],
                   requested_by_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind'],
                   requested_at: [:string, nullable: true],
                   confirmed_at: [:string, nullable: true],
                   canceled_at: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :status, :metadata,
                     requested_at: :iso8601, confirmed_at: :iso8601, canceled_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :order, :return, :exchange, :claim

          actor_attributes :requested_by

          many :actions, resource: proc { Spree.api.admin_order_change_action_serializer }
        end
      end
    end
  end
end
