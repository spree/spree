require_dependency 'spree/calculator'

module Spree
  module Calculator::Promotion
    class FlatPercent < Calculator
      preference :percent, :decimal, default: 0

      def self.description
        Spree.t(:flat_percent)
      end

      def compute(object, _line_items_total = nil)
        computed_amount = (object.amount * preferred_percent / 100).round(2)

        if computed_amount > object.amount
          object.amount
        else
          computed_amount
        end
      end
    end
  end
end
