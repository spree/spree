class ShippingRate < ActiveRecord::Base
  belongs_to :shipping_method
  belongs_to :shipping_category
  
  has_calculator
end
