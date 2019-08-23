require_dependency 'spree/calculator'

module Spree
  module Calculator::Promotion
    class FlatRate < Calculator
      preference :amount, :decimal, default: 0
      preference :currency, :string, default: -> { Spree::Config[:currency] }

      def self.description
        Spree.t(:flat_rate)
      end

      def compute(object = nil, line_items_total = 0)
        if object && preferred_currency.casecmp(object.currency.upcase).zero?
          
          if line_items_total == 0
            preferred_amount
          else
            (preferred_amount / line_items_total) * object.amount
          end
        else
          0
        end
      end
    end
  end
end
