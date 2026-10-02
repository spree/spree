module Spree
  module Api
    module V3
      class DeliveryZoneSerializer < BaseSerializer
        typelize name: :string, description: [:string, nullable: true]

        attributes :name, :description

        expandable :many, :members, :delivery_zone_member_serializer
      end
    end
  end
end
