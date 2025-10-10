module Spree
  module Api
    module V2
      module Platform
        class AddressSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :country, serializer: Spree::Api::Dependencies.platform_country_serializer.constantize
          belongs_to :state, serializer: Spree::Api::Dependencies.platform_state_serializer.constantize
          belongs_to :user, serializer: Spree::Api::Dependencies.platform_user_serializer.constantize
        end
      end
    end
  end
end
