module Spree
  class ShipmentShippingMethod < ActiveRecord::Base
    belongs_to :shipment
    belongs_to :shipping_method

    attr_accessible :shipping_method, :selected
  end
end
