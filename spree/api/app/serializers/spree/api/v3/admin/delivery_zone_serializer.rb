module Spree
  module Api
    module V3
      module Admin
        class DeliveryZoneSerializer < V3::DeliveryZoneSerializer
          typelize delivery_method_ids: [:string, multi: true],
                   delivery_profile_id: :string,
                   delivery_origin_group_id: [:string, nullable: true]

          attributes created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :delivery_profile, :delivery_origin_group

          attribute :delivery_method_ids do |record|
            record.delivery_methods.map(&:prefixed_id)
          end

          many :members, resource: proc { Spree.api.admin_delivery_zone_member_serializer }, if: proc { expand?('members') }
        end
      end
    end
  end
end
