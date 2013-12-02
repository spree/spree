module Spree
  class ShippingCalculator < Calculator


    def compute_shipment(shipment)
      compute(shipment.to_package)
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

