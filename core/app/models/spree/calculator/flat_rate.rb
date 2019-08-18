require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatRate < Calculator
    preference :amount, :decimal, default: 0
    preference :currency, :string, default: -> { Spree::Config[:currency] }

    def self.description
      Spree.t(:flat_rate_per_order)
    end

    def compute(object = nil, line_item_value = nil, line_items_total_value = nil)
      if object && preferred_currency.casecmp(object.currency.upcase).zero?
        preferred_amount * (line_item_value / line_items_total_value)
      else
        0
      end
    end
  end
end
