require_dependency 'spree/calculator'

module Spree
  module Calculator::Promotion
    class FlatRate < Calculator
      preference :amount, :decimal, default: 0
      preference :currency, :string, default: -> { Spree::Config[:currency] }

      def self.description
        Spree.t(:flat_rate)
      end

      def compute(object = nil _object_a = nil, _object_b = nil, _object_c = nil)
        if object && preferred_currency.casecmp(object.currency.upcase).zero?
          if line_items_total == 0
            preferred_amount
          else
            # In this process we occasionnally get a rounding error of 1 penny.
            # Is there a way for the last line item to get calculated using
            # what ever is remaining from the preffered_amount and therfor the discount would always amount to the preffered amout.
            (preferred_amount / line_items_total) * object.amount
          end
        else
          0
        end
      end
    end
  end
end
