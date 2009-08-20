class Calculator::FlatPercentItemTotal < Calculator
  preference :flat_percent, :decimal, :default => 0

  def self.description
    I18n.t("flat_percent")
  end

  def self.register
    super                                
    Coupon.register_calculator(self)
    ShippingMethod.register_calculator(self)
    ShippingRate.register_calculator(self)
  end
  
  def compute(order)
    return if order.nil?
    order.item_total * self.preferred_flat_percent
  end  
end
