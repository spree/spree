require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatPercentItemTotal < Calculator
    preference :flat_percent, :decimal, default: 0

    def self.description
      Spree.t(:flat_percent)
    end

    def compute(object)
      amount_remaining = object.amount.to_f + object.adjustment_total.to_f
      computed_amount  = (object.amount * preferred_flat_percent / 100).round(2)

      # If multiple promotion actions are applied we want to make sure
      # that we don't cause the promotion adjustments to push the order
      # into a negative total. So we return the object amount + adjustment_total
      if computed_amount > amount_remaining
        amount_remaining
      else
        computed_amount
      end
    end
  end
end
