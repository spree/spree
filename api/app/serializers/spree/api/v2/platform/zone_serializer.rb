module Spree
  module Api
    module V2
      module Platform
        class ZoneSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :zone_members, serializer: Spree::Api::Dependencies.platform_zone_member_serializer.constantize
        end
      end
    end
  end
end
