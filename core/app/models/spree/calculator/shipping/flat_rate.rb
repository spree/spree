require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class FlatRate < ShippingCalculator
      preference :amount, :decimal, :default => 0
      preference :currency, :string, :default => Spree::Config[:currency]

      attr_accessible :preferred_amount, :preferred_currency

      def self.description
        Spree.t(:shipping_flat_rate_per_order)
      end

      def compute_package(package)
        self.preferred_amount
      end
    end
  end
end
