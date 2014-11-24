require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatPercentItemTotal < Calculator
    preference :flat_percent, :decimal, default: 0

    def self.description
      Spree.t(:flat_percent)
    end

    def compute(object)
      discounted_total = object.amount - object.adjustment_total
      computed_amount  = (discounted_total * preferred_flat_percent / 100).round(2)

      # We don't want to cause the promotion adjustments to push the order into a negative total.
      if computed_amount > discounted_total
        discounted_total
      else
        computed_amount
      end
    end
  end
end
