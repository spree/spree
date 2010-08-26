class Calculator::PerItem < Calculator
  preference :amount, :decimal, :default => 0

  def self.description
    I18n.t("flat_rate_per_item")
  end

  def self.register
    super
    ShippingMethod.register_calculator(self)
  end

  def compute(object=nil)
    self.preferred_amount * object.line_items.length
  end
end
