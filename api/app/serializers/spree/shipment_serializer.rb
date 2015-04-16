module Spree
  class ShipmentSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.shipment_attributes
    attributes :id, :tracking, :number, :cost, :shipped_at, :state, :manifest, :stock_location_name, :order_id

    has_many :shipping_rates
    has_many :shipping_methods
    has_many :adjustments

    has_one :selected_shipping_rate

    def manifest
      object.manifest.map do |item|
        {
          variant_id: item.variant.id,
          states: item.states,
          line_item: item.line_item,
          quantity: item.quantity
        }
      end
    end

    def order_id
      object.order.number
    end

    def stock_location_name
      object.stock_location.name
    end
  end
end
