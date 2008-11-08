class ShippingMethod < ActiveRecord::Base
  belongs_to :zone

  def available?(order)
    zone.include?(order.address)
  end
  
  def calculate_shipping(order)
    return 0 unless zone.include?(order.address)
    return shipping_calculator.constantize.new.send(:calculate_shipping, order)
  end
end
