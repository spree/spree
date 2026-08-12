module Spree
  module Api
    module V3
      module Admin
        class DeliveryZoneSerializer < V3::DeliveryZoneSerializer
          typelize delivery_method_ids: [:string, multi: true],
                   delivery_profile_id: :string,
                   delivery_origin_group_id: [:string, nullable: true]

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :delivery_profile_id do |record|
            record.delivery_profile&.prefixed_id
          end

          attribute :delivery_origin_group_id do |record|
            record.delivery_origin_group&.prefixed_id
          end

          attribute :delivery_method_ids do |record|
            record.delivery_methods.map(&:prefixed_id)
          end

          many :members, resource: proc { Spree.api.admin_delivery_zone_member_serializer }, if: proc { expand?('members') }
        end
      end
    end
  end
end
