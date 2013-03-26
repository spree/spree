module Spree
  class ShippingCalculator < Calculator
    belongs_to :calculable, :polymorphic => true

    def compute(package)
      raise(NotImplementedError, 'please use concrete calculator')
    end

    def available?(package)
      true
    end

    private
    def total(content_items)
      content_items.sum { |item| item.quantity * item.variant.price }
    end
  end
end
