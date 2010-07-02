class Calculator::FlatPercentItemTotal < Calculator
  preference :flat_percent, :decimal, :default => 0

  def self.description
    I18n.t("flat_percent")
  end

  def self.register
    super                                
    Promotion.register_calculator(self)
    ShippingMethod.register_calculator(self)
    ShippingRate.register_calculator(self)
  end

  def compute(line_items)
    return if line_items.nil?
    item_total = line_items.inject(0) {|amount, li| amount + li.total } 
    item_total * self.preferred_flat_percent / 100.0
  end
end
