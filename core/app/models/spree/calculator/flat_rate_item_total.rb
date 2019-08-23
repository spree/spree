require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatRateItemTotal < Calculator
    preference :amount, :decimal, default: 0
    preference :currency, :string, default: -> { Spree::Config[:currency] }

    def self.description
      Spree.t(:flat_rate_item_total)
    end

    def compute(object = nil, line_items_total = 0)
      order = object.order

      if object && preferred_currency.casecmp(object.currency.upcase).zero?
        (preferred_amount / line_items_total) * object.amount
      else
        0
      end
    end

  end
end
