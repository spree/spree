require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatPercentItemTotal < Calculator
    preference :flat_percent, :decimal, default: 0

    def self.description
      Spree.t(:flat_percent)
    end

    def compute(order)
      item_total = accumulated_item_total(order) || order.amount
      return item_total if preferred_flat_percent >= 100
      (item_total * preferred_flat_percent / 100).round(2)
    end
  end
end
