require_dependency 'spree/shipping_calculator'
# For #to_d method on Ruby 1.8
require 'bigdecimal/util'

module Spree
  module Calculator::Shipping
    class PriceSack < ShippingCalculator
      preference :minimal_amount, :decimal, default: 0
      preference :normal_amount, :decimal, default: 0
      preference :discount_amount, :decimal, default: 0
      preference :currency, :string, default: ->{ Spree::Config[:currency] }

      def self.description
        Spree.t(:shipping_price_sack)
      end

      def compute_package(package)
        content_items = package.contents
        if total(content_items) < self.preferred_minimal_amount
          self.preferred_normal_amount
        else
          self.preferred_discount_amount
        end
      end
    end
  end
end
