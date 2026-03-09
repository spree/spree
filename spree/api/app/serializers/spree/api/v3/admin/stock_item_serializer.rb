module Spree
  module Api
    module V3
      module Admin
        class StockItemSerializer < V3::StockItemSerializer
          one :stock_location,
              resource: Spree.api.admin_stock_location_serializer,
              if: proc { expand?('stock_location') }

          one :variant,
              resource: Spree.api.admin_variant_serializer,
              if: proc { expand?('variant') }
        end
      end
    end
  end
end
