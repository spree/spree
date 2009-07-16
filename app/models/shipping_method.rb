class ShippingMethod < ActiveRecord::Base
  belongs_to :zone
  has_one :calculator, :as => :calculable, :dependent => :destroy
                                    
  accepts_nested_attributes_for :calculator
   
  def calculator_type
    calculator.class.to_s if calculator
  end
  
  def calculator_type=(calculator_type)
    # does nothing - just here to satisfy the form
  end
  
  def calculate_shipping(shipment)
    return 0 unless zone.include?(shipment.address)
    return calculator.calculate_shipping(shipment)
  end   
  
  def available?(order)
    return true unless calculator.respond_to?(:available?)
    calculator.available?(order)    
  end
end
