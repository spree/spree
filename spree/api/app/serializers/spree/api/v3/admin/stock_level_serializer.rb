module Spree
  module Api
    module V3
      module Admin
        class StockLevelSerializer < V3::StockLevelSerializer
          include Concerns::ExternalReferencesAttribute

          typelize metadata: 'Record<string, unknown>',
                   allocated_count: :number, available_count: :number

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          # Units promised to placed orders but not yet dispatched. Raised by an
          # `allocated` movement and retired by `released` or `shipped`, so an
          # oversell reads as this exceeding count_on_hand.
          attribute :allocated_count do |stock_level|
            stock_level.allocated_count.to_i
          end

          # Physical stock minus allocated units (per stock_level).
          attribute :available_count do |stock_level|
            stock_level.available_count.to_i
          end

          one :stock_location,
              resource: proc { Spree.api.admin_stock_location_serializer },
              if: proc { expand?('stock_location') }

          one :variant,
              resource: proc { Spree.api.admin_variant_serializer },
              if: proc { expand?('variant') }
        end
      end
    end
  end
end
