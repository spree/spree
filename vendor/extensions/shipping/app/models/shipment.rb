class Shipment < ActiveRecord::Base
  belongs_to :order
  belongs_to :shipping_method
  before_create :calculate_shipping
  
  def calculate_shipping
    calculator = shipping_method.shipping_calculator.constantize.new
    order.update_attribute(:ship_amount, calculator.calculate_shipping(order))
  end
end
