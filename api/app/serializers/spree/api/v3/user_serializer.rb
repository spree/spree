module Spree
  module Api
    module V3
      class UserSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            email: resource.email,
            first_name: resource.first_name,
            last_name: resource.last_name,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }
        end
      end
    end
  end
end
