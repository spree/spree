class Calculator::FlatRate < Calculator
  preference :amount, :decimal, :default => 0

  def self.description
    I18n.t("flat_rate_per_order")
  end

  def self.register
    super                                
    Promotion.register_calculator(self)
    ShippingMethod.register_calculator(self)
    ShippingRate.register_calculator(self)
  end  
  
  def compute(object=nil)
    self.preferred_amount
  end  
end
