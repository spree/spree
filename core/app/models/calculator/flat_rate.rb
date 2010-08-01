class Calculator::FlatRate < Calculator
  preference :amount, :decimal, :default => 0

  def self.description
    I18n.t("flat_rate_per_order")
  end

  def self.register
    super
    ShippingMethod.register_calculator(self)
  end

  def compute(object=nil)
    self.preferred_amount
  end
end
