class Shipment < ActiveRecord::Base
  belongs_to :order
  belongs_to :shipping_method
  before_save :calculate_shipping
  
  private 
  def calculate_shipping
    calculator = shipping_method.shipping_calculator.constantize.new
    order.update_attribute(:ship_amount, calculator.calculate_shipping(order))
  end
end
