require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatRate < Calculator
    preference :amount, :decimal, :default => 0

    attr_accessible :preferred_amount

    def self.description
      I18n.t(:flat_rate_per_order)
    end

    def compute(object=nil)
      self.preferred_amount
    end
  end
end
