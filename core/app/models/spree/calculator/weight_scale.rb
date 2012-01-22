module Spree
  class Calculator::WeightScale < Calculator
    preference :rule, :string
    preference :default_weight, :decimal, :default => 1
    preference :default_price, :decimal, :default => 0

    def self.description
      I18n.t(:weight_scale)
    end

    # as object we always get line items, as calculable we have Coupon, ShippingMethod
    def compute(object)
      line_items = object.is_a?(Order) ? object.line_items : object

      if self.preferred_rule =~ /^(\d*\:\d*\;)*$|^(\d*\:\d*\;)*(\d*\:\d*)$/

        total_weight = line_items.sum do |li|
            (li.variant.weight || self.preferred_default_weight) * li.quantity
        end
        self.preferred_rule.split(";").each do |rule|
          weight, price = rule.split(":")
          return price.to_f if total_weight.to_f < weight.to_f
        end
      end
      return self.preferred_default_price.to_f
    end
  end
end