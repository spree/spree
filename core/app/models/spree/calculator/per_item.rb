module Spree
  class Calculator::PerItem < Calculator
    preference :amount, :decimal, :default => 0

    def self.description
      I18n.t(:flat_rate_per_item)
    end

    def compute(object=nil)
      return 0 if object.nil?
      self.preferred_amount * object.line_items.reduce(0) do |sum, value|
        sum + value.quantity
      end
    end
  end
end
