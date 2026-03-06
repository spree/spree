module Spree
  module Api
    module V3
      module Admin
        class ShipmentSerializer < V3::ShipmentSerializer
          typelize metadata: 'Record<string, unknown> | null',
                   order_id: [:string, nullable: true],
                   stock_location_id: [:string, nullable: true]

          attribute :metadata do |shipment|
            shipment.metadata.presence
          end

          attribute :order_id do |shipment|
            shipment.order&.prefixed_id
          end

          attribute :stock_location_id do |shipment|
            shipment.stock_location&.prefixed_id
          end
        end
      end
    end
  end
end
