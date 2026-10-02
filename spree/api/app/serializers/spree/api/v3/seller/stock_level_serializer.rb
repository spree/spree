module Spree
  module Api
    module V3
      module Seller
        # What a seller holds of one variant at one of their locations.
        class StockLevelSerializer < V3::StockLevelSerializer
          typelize allocated_count: :number, available_count: :number

          attributes created_at: :iso8601, updated_at: :iso8601

          # Units promised to placed orders but not yet dispatched.
          attribute :allocated_count do |stock_level|
            stock_level.allocated_count.to_i
          end

          attribute :available_count do |stock_level|
            stock_level.available_count.to_i
          end

          one :stock_location,
              resource: proc { Spree.api.seller_stock_location_serializer },
              if: proc { expand?('stock_location') }
        end
      end
    end
  end
end
