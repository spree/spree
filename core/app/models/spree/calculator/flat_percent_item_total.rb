require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatPercentItemTotal < Calculator
    preference :flat_percent, :decimal, default: 0

    def self.description
      Spree.t(:flat_percent)
    end

    def compute(order)
      return accumulated_item_total(order) if preferred_flat_percent >= 100
      (accumulated_item_total(order) * preferred_flat_percent / 100).round(2)
    end

  end
end
