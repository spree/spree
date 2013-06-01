module Spree
  class ShippingCalculator < Calculator
    def compute(package_or_shipment)
      package = package_or_shipment.respond_to?(:to_package) ?
                  package_or_shipment.to_package : package_or_shipment
      compute_package package
    end

    def compute_package(package)
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

