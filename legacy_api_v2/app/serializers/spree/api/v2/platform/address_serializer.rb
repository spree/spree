module Spree
  module Api
    module V2
      module Platform
        class AddressSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :country, serializer: Spree.api.platform_country_serializer
          belongs_to :state, serializer: Spree.api.platform_state_serializer
          belongs_to :user, serializer: Spree.api.platform_user_serializer
        end
      end
    end
  end
end
