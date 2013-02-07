module Spree
  class Calculator::FreeShipping < Calculator
    def self.description
      Spree.t(:free_shipping)
    end

    def compute(object)
      if object.is_a?(Array)
        return if object.empty?
        order = object.first.order
      else
        order = object
      end

      order.ship_total
    end
  end
end

