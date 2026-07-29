module Spree
  module Api
    module V3
      class DeliveryZoneSerializer < BaseSerializer
        typelize name: :string, description: [:string, nullable: true]

        attributes :name, :description

        many :members, resource: proc { Spree.api.delivery_zone_member_serializer }
      end
    end
  end
end
