module Spree
  module Api
    module V2
      module Platform
        class StateChangeSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :user, serializer: Spree::Api::Dependencies.platform_user_serializer.constantize
        end
      end
    end
  end
end
