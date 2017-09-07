module Spree
  class ReturnsCalculator < Calculator
    def compute(_return_item)
      raise NotImplementedError, "Please implement 'compute(return_item)' in your calculator: #{self.class.name}"
    end
  end
end
