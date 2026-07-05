module Spree
  module Api
    module V3
      module Admin
        class DeliveryRateSerializer < V3::DeliveryRateSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          one :shipping_method, key: :delivery_method, resource: proc { Spree.api.admin_delivery_method_serializer }, if: proc { expand?('delivery_method') }
        end
      end
    end
  end
end
