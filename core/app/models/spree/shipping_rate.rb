module Spree
  class ShippingRate < Spree::Base
    belongs_to :shipment, class_name: 'Spree::Shipment'
    belongs_to :shipping_method, class_name: 'Spree::ShippingMethod', inverse_of: :shipping_rates
    belongs_to :tax_rate, class_name: 'Spree::TaxRate'

    delegate :order, :currency, to: :shipment
    delegate :name, to: :shipping_method

    extend Spree::DisplayMoney

    money_methods :base_price, :tax_amount

    def base_price
      cost
    end

    def display_price
      price = display_base_price.to_s

      return price if tax_rate.nil? || tax_amount == 0

      Spree.t tax_rate.included_in_price? ? :including_tax : :excluding_tax,
              scope: "shipping_rates.display_price",
              price: price,
              tax_amount: display_tax_amount,
              tax_rate_name: tax_rate.name
    end
    alias_method :display_cost, :display_price

    def tax_amount
      @_tax_amount ||= tax_rate.calculator.compute_shipping_rate(self)
    end

    def shipping_method
      Spree::ShippingMethod.unscoped { super }
    end

    def shipping_method_code
      shipping_method.code
    end

    def tax_rate
      Spree::TaxRate.unscoped { super }
    end
  end
end
