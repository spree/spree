class ShippingMethod < ActiveRecord::Base
  belongs_to :zone
  belongs_to :shipping_category

  def available?(order)
    zone.include?(order.ship_address)
  end
  
  def calculate_shipping(order)
    return 0 unless zone.include?(order.ship_address)
    return shipping_calculator.constantize.send(:calculate_shipping, order)
  end
end
