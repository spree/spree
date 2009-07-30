class Calculator::FlatPercent < Calculator
  preference :flat_percent, :decimal, :default => 0

  def self.description
    I18n.t("flat_percent")
  end

  def self.register
    super                                
    Coupon.register_calculator(self)
    ShippingMethod.register_calculator(self)
  end
  
  def compute(object = nil)
    object ||= self.calculable

    if object.is_a?(Array)
      base = object.map{ |o|
        o.respond_to?(:amount) ? o.amount : o.to_d
      }.sum
    else
      base = object.respond_to?(:amount) ? object.amount : object.to_d
    end
    
    base * self.preferred_flat_percent
  end  
end
