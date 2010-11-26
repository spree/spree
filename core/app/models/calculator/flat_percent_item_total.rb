class Calculator::FlatPercentItemTotal < Calculator
  preference :flat_percent, :decimal, :default => 0

  def self.description
    I18n.t("flat_percent")
  end

  def self.register
    super
    ShippingMethod.register_calculator(self)
  end

  def compute(object)
    return unless object.present? and object.line_items.present?
    item_total = object.line_items.map(&:amount).sum
    value = item_total * self.preferred_flat_percent / 100.0
    (value * 100).round.to_f / 100
  end
end
