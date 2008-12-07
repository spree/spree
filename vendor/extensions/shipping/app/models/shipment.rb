class Shipment < ActiveRecord::Base
  before_create :generate_shipment_number
  belongs_to :order
  belongs_to :shipping_method
  before_create :calculate_shipping
    
  private
  
  def calculate_shipping
    calculator = shipping_method.shipping_calculator.constantize.new
    order.update_attribute(:ship_amount, calculator.calculate_shipping(order))
  end
  
  def generate_shipment_number
    record = true
    while record
      random = Array.new(11){rand(9)}.join
      record = Shipment.find(:first, :conditions => ["number = ?", random])
    end
    self.number = random
  end
  
end
