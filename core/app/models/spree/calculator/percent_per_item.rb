module Spree

  # A calculator for promotions that calculates a percent-off discount
  # for all matching products in an order. This should not be used as a
  # shipping calculator since it would be the same thing as a flat percent
  # off the entire order.

  class Calculator::PercentPerItem < Calculator
    preference :percent, :decimal, :default => 0

    attr_accessible :preferred_percent

    def self.description
      Spree.t(:percent_per_item)
    end

    def compute(object=nil)
      return 0 if object.nil?
      object.line_items.reduce(0) do |sum, line_item|
        sum += value_for_line_item(line_item)
      end
    end

  private

    # Returns all products that match this calculator, but only if the calculator
    # is attached to a promotion. If attached to a ShippingMethod, nil is returned.
    # Copied from per_item.rb
    def matching_products
      if compute_on_promotion?
        self.calculable.promotion.rules.map do |rule|
          rule.respond_to?(:products) ? rule.products : []
        end.flatten
      end
    end

    def value_for_line_item(line_item)
      if compute_on_promotion?
        return 0 unless matching_products.blank? or matching_products.include?(line_item.product)
      end
      ((line_item.price * line_item.quantity) * preferred_percent) / 100
    end

    # Determines wether or not the calculable object is a promotion
    def compute_on_promotion?
      @compute_on_promotion ||= self.calculable.respond_to?(:promotion)
    end
  end
end
