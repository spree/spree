class ShippingMethod < ActiveRecord::Base
  belongs_to :zone

  def available?(shipment)
    zone.include?(shipment.address)
  end
  
  def calculate_shipping(shipment)
    return 0 unless zone.include?(shipment.address)
    return shipping_calculator.constantize.new.send(:calculate_shipping, shipment)
  end
end
