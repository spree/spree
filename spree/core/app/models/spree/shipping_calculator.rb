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

    # Whether this calculator can quote the given currency. Amount-based
    # calculators override via Calculator::CurrencyAmounts; percent and
    # per-weight math is currency-agnostic and quotes anything.
    def supports_currency?(_currency)
      true
    end

    private

    def total(content_items)
      content_items.sum(&:amount)
    end
  end
end
