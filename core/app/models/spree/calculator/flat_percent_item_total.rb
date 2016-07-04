require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatPercentItemTotal < Calculator
    preference :flat_percent, :decimal, :default => 0

    attr_accessible :preferred_flat_percent

    def self.description
      I18n.t(:flat_percent)
    end

    def compute(object)
      item_total = line_items_for(object).map(&:amount).sum
      value = item_total * BigDecimal(self.preferred_flat_percent.to_s) / 100.0
      (value * 100).round.to_f / 100
    end
  end
end
