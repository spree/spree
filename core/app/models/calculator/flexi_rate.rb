class Calculator::FlexiRate < Calculator
  preference :first_item,      :decimal, :default => 0
  preference :additional_item, :decimal, :default => 0
  preference :max_items,       :decimal, :default => 0

  def self.description
    I18n.t("flexible_rate")
  end

  def self.available?(object)
    true
  end

  def self.register
    super
    Promotion.register_calculator(self)
    ShippingMethod.register_calculator(self)
    ShippingRate.register_calculator(self)
  end

  def compute(object)
    sum = 0
    max = self.preferred_max_items
    items_count = object.inject(0) {|count, line_item| count + line_item.quantity }
    items_count.times do |i|
      if (i % max == 0) && (max > 0)
        sum += self.preferred_first_item
      else
        sum += self.preferred_additional_item
      end
    end
    return(sum)
  end  
end
