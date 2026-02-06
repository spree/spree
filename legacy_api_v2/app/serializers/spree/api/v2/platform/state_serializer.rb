module Spree
  module Api
    module V2
      module Platform
        class StateSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :country, serializer: Spree.api.platform_country_serializer
        end
      end
    end
  end
end
