require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class PerItem < ShippingCalculator
      preference :amount, :decimal, default: 0
      preference :currency, :string, default: Spree::Config[:currency]

      def self.description
        Spree.t(:shipping_flat_rate_per_item)
      end

      def compute_package(package)
        content_items = package.contents
        self.preferred_amount * content_items.sum { |item| item.quantity }
      end
    end
  end
end
