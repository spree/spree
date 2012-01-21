module Spree
  class Calculator::WeightRate < Calculator
    preference :default_rule, :string
    preference :default_weight, :decimal, :default => 1
    preference :default_price, :decimal, :default => 0

    def self.description
      I18n.t(:weight_rate)
    end

    # as object we always get line items, as calculable we have Coupon, ShippingMethod
    def compute(object)
      line_items = object.is_a?(Order) ? object.line_items : object

      if self.preferred_default_rule =~ /^(\d*\:\d*\;)*$|^(\d*\:\d*\;)*(\d*\:\d*)$/

        total_weight = line_items.map{|li|
            (li.variant.weight || self.preferred_default_weight) * li.quantity
          }.sum
        self.preferred_default_rule.split(";").each do |rule|
          weight, price = rule.split(":")
          return price.to_f if total_weight.to_f < weight.to_f
        end
      end
      return self.preferred_default_price.to_f
    end
  end
end