module Spree
  module Api
    module V2
      module Platform
        class CountrySerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :states, serializer: Spree::Api::Dependencies.platform_state_serializer.constantize
        end
      end
    end
  end
end
