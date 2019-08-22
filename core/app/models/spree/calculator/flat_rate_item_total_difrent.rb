require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatRateItemTotal < Calculator
    preference :amount, :decimal, default: 0
    preference :currency, :string, default: -> { Spree::Config[:currency] }

    def self.description
      Spree.t(:flat_rate_item_total)
    end

    def compute(object = nil)
      order = object.order
      # Is it possible to get the total amount from all promotion applicable line items 
      flat_percent = (preferred_amount * 100) / (order.amount)

      if object && preferred_currency.casecmp(object.currency.upcase).zero?
        computed_amount = (object.amount * flat_percent / 100)

        # We don't want to cause the promotion adjustments to push the order into a negative total.
        if computed_amount > object.amount
          object.amount
        else
          computed_amount
        end

      else
        0
      end
    end

  end
end
