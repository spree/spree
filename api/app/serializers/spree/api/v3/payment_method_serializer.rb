module Spree
  module Api
    module V3
      class PaymentMethodSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            name: resource.name,
            description: resource.description,
            type: resource.type,
            active: resource.active,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }
        end
      end
    end
  end
end
