module Spree
  module Api
    module V2
      module Platform
        class StateSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :country, serializer: Spree::Api::Dependencies.platform_country_serializer.constantize
        end
      end
    end
  end
end
