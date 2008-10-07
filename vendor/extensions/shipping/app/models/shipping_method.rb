class ShippingMethod < ActiveRecord::Base
  belongs_to :zone
  belongs_to :shipping_category

  def available?(order)
    # TODO
  end
  
  def calculate_shipping(order)
    # TODO
  end
end
