require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatRateItemTotal < Calculator
    include Spree::AdjustmentSource
    preference :amount, :decimal, default: 0
    preference :currency, :string, default: -> { Spree::Config[:currency] }

    def self.description
      Spree.t(:flat_rate_item_total)
    end

    def compute(object = nil)

      order = object.order

      if object && preferred_currency.casecmp(object.currency.upcase).zero?
        (preferred_amount / order.amount) * object.amount
      else
        0
      end
    end

  end
end
