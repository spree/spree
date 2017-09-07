require_dependency 'spree/calculator'

module Spree
  class Calculator::PriceSack < Calculator
    preference :minimal_amount, :decimal, default: 0
    preference :normal_amount, :decimal, default: 0
    preference :discount_amount, :decimal, default: 0
    preference :currency, :string, default: -> { Spree::Config[:currency] }

    def self.description
      Spree.t(:price_sack)
    end

    # as object we always get line items, as calculable we have Coupon, ShippingMethod
    def compute(object)
      base = if object.is_a?(Array)
               object.map { |o| o.respond_to?(:amount) ? o.amount : BigDecimal(o.to_s) }.sum
             else
               object.respond_to?(:amount) ? object.amount : BigDecimal(object.to_s)
             end

      if base < preferred_minimal_amount
        preferred_normal_amount
      else
        preferred_discount_amount
      end
    end
  end
end
