require_dependency 'spree/calculator'

module Spree
  class Calculator::PriceSack < Calculator
    preference :minimal_amount, :decimal, :default => 0
    preference :normal_amount, :decimal, :default => 0
    preference :discount_amount, :decimal, :default => 0

    attr_accessible :preferred_minimal_amount,
                    :preferred_normal_amount,
                    :preferred_discount_amount

    def self.description
      I18n.t(:price_sack)
    end

    # as object we always get line items, as calculable we have Coupon, ShippingMethod
    def compute(object)
      if object.is_a?(Array)
        base = object.map { |o| o.respond_to?(:amount) ? o.amount : o.to_d }.sum
      else
        base = object.respond_to?(:amount) ? object.amount : object.to_d
      end

      if base >= self.preferred_minimal_amount
        self.preferred_normal_amount
      else
        self.preferred_discount_amount
      end
    end
  end
end
