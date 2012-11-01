module Spree
  class ShippingRate < Struct.new(:id, :shipping_method, :name, :cost)
    def initialize(attributes = {})
      attributes.each do |k, v|
        self.send("#{k}=", v)
      end
    end

    def display_price
      if Spree::Config[:shipment_inc_vat]
        price = (1 + Spree::TaxRate.default) * cost
      else
        price = cost
      end

      Spree::Money.new(price)
    end
  end
end
