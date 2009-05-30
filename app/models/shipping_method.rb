class ShippingMethod < ActiveRecord::Base
  belongs_to :zone

  def calculate_shipping(order)
    return 0 unless zone.include?(order.ship_address)
    return shipping_calculator.constantize.new.send(:calculate_shipping, order)
  end   
  
  def available?(order)
    calculator = shipping_calculator.constantize.new                               
    return true unless calculator.respond_to?(:available?)
    calculator.available?(order)    
  end
end
