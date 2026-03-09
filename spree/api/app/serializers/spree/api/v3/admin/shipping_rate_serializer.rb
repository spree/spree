module Spree
  module Api
    module V3
      module Admin
        class ShippingRateSerializer < V3::ShippingRateSerializer
          one :shipping_method, resource: Spree.api.admin_shipping_method_serializer, if: proc { expand?('shipping_method') }
        end
      end
    end
  end
end
