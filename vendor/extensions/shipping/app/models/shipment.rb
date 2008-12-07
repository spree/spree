class Shipment < ActiveRecord::Base
  before_create :generate_shipment_number
  belongs_to :order
  belongs_to :shipping_method
  before_create :calculate_shipping
  after_save :transition_order
    
  def shipped?
    self.shipped_at
  end
    
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
  
  def transition_order
    order.shipments.each do |shipment|
      return unless shipment.shipped?
    end
    # transition order to shipped if all shipments have been shipped
    order.ship!
  end
end
