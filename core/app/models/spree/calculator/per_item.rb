module Spree
  class Calculator::PerItem < Calculator
    preference :amount, :decimal, :default => 0

    attr_accessible :preferred_amount

    def self.description
      I18n.t(:flat_rate_per_item)
    end

    def compute(object=nil)
      return 0 if object.nil?
      self.preferred_amount * object.line_items.reduce(0) do |sum, value|
        value_to_add = (target_products().include?(value.product) ? value.quantity : 0)
        sum + value_to_add
      end
    end

    def target_products
      #TODO: product groups?
      self.calculable.promotion.rules.map(&:products).flatten
    end
  end
end
