module Spree
  module Api
    module V3
      module Admin
        class StockItemSerializer < V3::StockItemSerializer
          typelize metadata: 'Record<string, unknown>',
                   allocated_count: :number, available_count: :number

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          # Units already allocated to pending shipments. Always 0 in 5.5;
          # 6.0 Typed Stock Movements wires it up.
          attribute :allocated_count do |stock_item|
            stock_item.allocated_count.to_i
          end

          # Physical stock minus allocated units (per stock_item).
          attribute :available_count do |stock_item|
            stock_item.available_count.to_i
          end

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
