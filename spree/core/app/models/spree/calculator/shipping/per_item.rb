require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class PerItem < ShippingCalculator
      include Spree::Calculator::CurrencyAmounts

      preference :amount, :decimal, default: 0
      preference :currency, :string, default: -> { Spree::Store.default.default_currency }

      def self.description
        Spree.t(:shipping_flat_rate_per_item)
      end

      def compute_package(package)
        compute_from_quantity(package.contents.sum(&:quantity), currency: package.currency)
      end

      def compute_from_quantity(quantity, currency: nil)
        per_item = currency ? amount_for(currency) : preferred_amount
        return nil if per_item.nil?

        per_item * quantity
      end
    end
  end
end
