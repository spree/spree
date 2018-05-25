require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class FlexiRate < ShippingCalculator
      preference :first_item,      :decimal, default: 0.0
      preference :additional_item, :decimal, default: 0.0
      preference :max_items,       :integer, default: 0
      preference :currency,        :string,  default: -> { Spree::Config[:currency] }

      def self.description
        Spree.t(:shipping_flexible_rate)
      end

      def compute_package(package)
        quantity = package.contents.sum(&:quantity)

        compute_from_quantity(quantity)
      end

      delegate :compute_from_quantity, to: :flexi_rate_calculator

      private

      def flexi_rate_calculator
        ::Spree::Calculator::FlexiRate.new(
          preferred_additional_item: preferred_additional_item,
          preferred_first_item:      preferred_first_item,
          preferred_max_items:       preferred_max_items,
          preferred_currency:        preferred_currency
        )
      end
    end
  end
end
