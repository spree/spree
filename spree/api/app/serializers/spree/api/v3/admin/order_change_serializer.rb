module Spree
  module Api
    module V3
      module Admin
        class OrderChangeSerializer < V3::OrderChangeEventSerializer
          typelize status: [:string, enum: Spree::OrderChange.statuses, enum_type_name: 'OrderChangeStatus'],
                   requested_by_id: [:string, nullable: true],
                   requested_by_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind'],
                   metadata: 'Record<string, unknown>'

          attributes :metadata

          actor_attributes :requested_by

          many :actions, resource: proc { Spree.api.admin_order_change_action_serializer }
        end
      end
    end
  end
end
