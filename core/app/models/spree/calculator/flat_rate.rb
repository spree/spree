require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatRate < Calculator
    preference :amount, :decimal, default: 0
    preference :currency, :string, default: ->{ Spree::Config[:currency] }

    def self.description
      Spree.t(:flat_rate_per_order)
    end

    def compute(object=nil)
      self.preferred_amount
    end
  end
end
