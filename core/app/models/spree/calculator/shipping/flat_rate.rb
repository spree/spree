require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class FlatRate < ShippingCalculator
      preference :amount, :decimal, default: 0
      preference :currency, :string, default: -> { Spree::Store.default.default_currency }

      preference :minimum_item_total, :decimal, default: nil, nullable: true
      preference :maximum_item_total, :decimal, default: nil, nullable: true

      preference :minimum_weight, :decimal, default: nil, nullable: true
      preference :maximum_weight, :decimal, default: nil, nullable: true

      def self.description
        Spree.t(:shipping_flat_rate_per_order)
      end

      def compute_package(package)
        return nil if preferred_minimum_weight.present? && preferred_minimum_weight >= package.weight
        return nil if preferred_maximum_weight.present? && preferred_maximum_weight < package.weight

        return nil if preferred_minimum_item_total.present? && preferred_minimum_item_total >= package.item_total
        return nil if preferred_maximum_item_total.present? && preferred_maximum_item_total < package.item_total

        preferred_amount
      end
    end
  end
end
