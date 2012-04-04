module Spree
  class Calculator::PerItem < Calculator
    preference :amount, :decimal, :default => 0

    attr_accessible :preferred_amount

    def self.description
      I18n.t(:flat_rate_per_item)
    end

    def compute(object=nil)
      self.preferred_amount * object.line_items.length
    end
  end
end
