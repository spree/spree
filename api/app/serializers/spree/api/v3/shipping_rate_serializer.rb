module Spree
  module Api
    module V3
      class ShippingRateSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            name: resource.name,
            cost: resource.cost.to_f,
            display_cost: resource.display_cost.to_s,
            selected: resource.selected,
            shipping_method_id: resource.shipping_method_id,
            shipping_method_code: resource.shipping_method&.code,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }
        end
      end
    end
  end
end
