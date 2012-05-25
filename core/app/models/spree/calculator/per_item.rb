module Spree
  class Calculator::PerItem < Calculator
    preference :amount, :decimal, :default => 0

    attr_accessible :preferred_amount

    def self.description
      I18n.t(:flat_rate_per_item)
    end

    def compute(object=nil)
      return 0 if object.nil?
      self.preferred_amount * object.line_items.reduce(0) do |sum, value|
        value_to_add = matching_products.include?(value.product) ? value.quantity : 0
        sum + value_to_add
      end
    end

    # Returns all products that match this calculator, but only if the calculator
    # is attached to a promotion. If attached to a ShippingMethod, nil is returned.
    def matching_products
      # Regression check for #1596
      # Calculator::PerItem can be used in two cases.
      # The first is in a typical promotion, providing a discount per item of a particular item
      # The second is a ShippingMethod, where it applies to an entire order
      #
      # Shipping methods do not have promotions attached, but promotions do
      # Therefore we must check for promotions
      if self.calculable.respond_to?(:promotion)
        self.calculable.promotion.rules.map(&:products).flatten
      end
    end
  end
end
