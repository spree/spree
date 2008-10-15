class Shipment < ActiveRecord::Base
  belongs_to :order
  belongs_to :shipping_method
end
