require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class FlatRate < ShippingCalculator
      include Spree::Calculator::CurrencyAmounts

      preference :amount, :decimal, default: 0
      # @deprecated Together with the single `amount`, superseded by the
      #   per-currency `amounts` hash; kept as the fallback for its own
      #   currency so upgraded stores quote unchanged.
      preference :currency, :string, default: -> { Spree::Store.default.default_currency }

      preference :minimum_item_total, :decimal, default: nil, nullable: true, deprecated: 'Use a Spree::DeliveryMethodRules rule on the delivery method instead; removed in Spree 6.1.'
      preference :maximum_item_total, :decimal, default: nil, nullable: true, deprecated: 'Use a Spree::DeliveryMethodRules rule on the delivery method instead; removed in Spree 6.1.'

      preference :minimum_weight, :decimal, default: nil, nullable: true, deprecated: 'Use a Spree::DeliveryMethodRules rule on the delivery method instead; removed in Spree 6.1.'
      preference :maximum_weight, :decimal, default: nil, nullable: true, deprecated: 'Use a Spree::DeliveryMethodRules rule on the delivery method instead; removed in Spree 6.1.'

      def self.description
        Spree.t(:shipping_flat_rate_per_order)
      end

      def compute_package(package)
        return nil if preferred_minimum_weight.present? && preferred_minimum_weight >= package.weight
        return nil if preferred_maximum_weight.present? && preferred_maximum_weight < package.weight

        return nil if preferred_minimum_item_total.present? && preferred_minimum_item_total >= package.item_total
        return nil if preferred_maximum_item_total.present? && preferred_maximum_item_total < package.item_total

        amount_for(package.currency)
      end
    end
  end
end
