module Spree
  module Api
    module V2
      module Platform
        class ZoneMemberSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :zoneable, polymorphic: true
        end
      end
    end
  end
end
