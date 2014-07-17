module Spree
  class Calculator
    class PercentOnLineItem < Calculator
      preference :percent, :decimal, default: 0

      def self.description
        Spree.t(:percent_per_item)
      end

      def compute(object)
        (object.amount * preferred_percent) / 100
      end
    end
  end
end
