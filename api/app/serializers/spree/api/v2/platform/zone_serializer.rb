module Spree
  module Api
    module V2
      module Platform
        class ZoneSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :zone_members, serializer: Spree.api.platform_zone_member_serializer
        end
      end
    end
  end
end
