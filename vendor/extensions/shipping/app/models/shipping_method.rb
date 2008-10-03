class ShippingMethod < ActiveRecord::Base
  belongs_to :zone
  #belongs_to :shipping_category
  
end
