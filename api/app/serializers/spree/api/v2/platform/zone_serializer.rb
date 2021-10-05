module Spree
  module Api
    module V2
      module Platform
        class ZoneSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :zone_members
        end
      end
    end
  end
end
