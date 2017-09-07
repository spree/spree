require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class PriceSack < ShippingCalculator
      preference :minimal_amount, :decimal, default: 0
      preference :normal_amount, :decimal, default: 0
      preference :discount_amount, :decimal, default: 0
      preference :currency, :string, default: -> { Spree::Config[:currency] }

      def self.description
        Spree.t(:shipping_price_sack)
      end

      def compute_package(package)
        compute_from_price(total(package.contents))
      end

      def compute_from_price(price)
        if price < preferred_minimal_amount
          preferred_normal_amount
        else
          preferred_discount_amount
        end
      end
    end
  end
end
