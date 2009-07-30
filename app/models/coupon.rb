class Coupon < ActiveRecord::Base
  has_many :discounts 
  has_one :calculator, :as => :calculable, :dependent => :destroy
      
  accepts_nested_attributes_for :calculator
  
  validates_presence_of :calculator
  validates_presence_of :code

  def calculator_type
    calculator.class.to_s if calculator
  end
  
  def calculator_type=(calculator_type)                                                                
    clazz = calculator_type.constantize if calculator_type
    self.calculator = clazz.new if clazz and not self.calculator.is_a? clazz
  end
  
  def eligible?(checkout)
    return false if expires_at and Time.now > expires_at
    return false if usage_limit and discounts.count >= usage_limit
    # TODO - also check items in the order (once we support product groups for coupons)
    true
  end
    
  def create_discount(checkout)
    return unless eligible?(checkout) and amount = calculator.calculate_discount(checkout)
    amount = checkout.order.item_total unless amount < checkout.order.item_total
    checkout.discounts.clear unless combine? and checkout.discounts.all? { |discount| discount.coupon.combine? }
    checkout.discounts.create(:coupon => self, :checkout => checkout, :amount => amount)
  end
end
