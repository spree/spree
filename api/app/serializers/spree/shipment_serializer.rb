module Spree
  class ShipmentSerializer < ActiveModel::Serializer
    attributes :id, :tracking, :number, :cost, :shipped_at, :state, :order_id,
               :stock_location_name, :manifest

    has_many :shipping_rates
    has_one :selected_shipping_rate
    has_many :shipping_methods
    
    def order_id
      object.order.number
    end

    def stock_location_name
      object.stock_location.name
    end

    def manifest
      object.manifest
    end
  end
end
