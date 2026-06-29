module Spree
  module Api
    module V3
      module Admin
        class ReturnAuthorizationSerializer < V3::ReturnAuthorizationSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          one :order,
              resource: proc { Spree.api.admin_order_serializer },
              if: proc { expand?('order') }

          one :stock_location,
              resource: proc { Spree.api.admin_stock_location_serializer },
              if: proc { expand?('stock_location') }
        end
      end
    end
  end
end
