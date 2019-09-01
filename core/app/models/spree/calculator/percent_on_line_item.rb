module Spree
  class Calculator
    class PercentOnLineItem < Calculator
      preference :percent, :decimal, default: 0

      def self.description
        Spree.t(:percent_per_item)
      end

      def compute(object)
        computed_amount = (object.amount * preferred_percent / 100).round(2)

        # We don't want to cause the promotion adjustments to push the order into a negative total.
        if computed_amount > object.amount
          object.amount
        else
          computed_amount
        end
      end
    end
  end
end
