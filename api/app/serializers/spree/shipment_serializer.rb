module Spree
  class ShipmentSerializer < ActiveModel::Serializer
    attributes :id, :tracking, :number, :cost, :shipped_at, :state, :order_id,
               :stock_location_name, :manifest

    has_many :shipping_rates
    has_many :shipping_methods

    has_one :selected_shipping_rate

    def manifest
      object.manifest.map do |item|
        { 
          variant: {
            id: item.variant.id,
            name: item.variant.name,
            sku: item.variant.sku,
            price: item.variant.price
          },
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
