module Spree
  class ShippingCalculator < Calculator
    def compute_shipment(_shipment)
      raise NotImplementedError, "Please implement 'compute_shipment(shipment)' in your calculator: #{self.class.name}"
    end

    def compute_package(_package)
      raise NotImplementedError, "Please implement 'compute_package(package)' in your calculator: #{self.class.name}"
    end

    def available?(_package)
      true
    end

    private

    def total(content_items)
      content_items.sum(&:amount)
    end
  end
end
