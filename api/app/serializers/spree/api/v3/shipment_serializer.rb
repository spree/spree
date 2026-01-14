module Spree
  module Api
    module V3
      class ShipmentSerializer < BaseSerializer
        attributes :id, :number, :state, :tracking,
                   shipped_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

        attribute :cost do |shipment|
          shipment.cost.to_f
        end

        attribute :display_cost do |shipment|
          shipment.display_cost.to_s
        end

        attribute :shipping_method do |shipment|
          next unless shipment.shipping_method

          {
            id: shipment.shipping_method.id,
            name: shipment.shipping_method.name,
            code: shipment.shipping_method.code
          }
        end

        attribute :stock_location do |shipment|
          next unless shipment.stock_location

          {
            id: shipment.stock_location.id,
            name: shipment.stock_location.name
          }
        end

        many :shipping_rates,
             resource: Spree.api.v3_storefront_shipping_rate_serializer,
             if: proc { params[:includes]&.include?('shipping_rates') }
      end
    end
  end
end
