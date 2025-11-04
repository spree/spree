module Spree
  module Api
    module V3
      class ShippingMethodSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            name: resource.name,
            code: resource.code,
            tracking_url: resource.tracking_url,
            admin_name: resource.admin_name,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }
        end
      end
    end
  end
end
