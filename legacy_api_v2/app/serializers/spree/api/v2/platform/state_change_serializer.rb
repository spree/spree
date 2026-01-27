module Spree
  module Api
    module V2
      module Platform
        class StateChangeSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :user, serializer: Spree.api.platform_user_serializer
        end
      end
    end
  end
end
