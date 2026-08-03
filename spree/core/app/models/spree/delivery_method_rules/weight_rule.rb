module Spree
  module DeliveryMethodRules
    # Bounds the method by the package weight (inclusive min/max). Compares
    # raw numbers in the store's implicit weight unit — the same semantics as
    # variant weights themselves.
    class WeightRule < Spree::DeliveryMethodRule
      preference :minimum_weight, :decimal, default: nil, nullable: true
      preference :maximum_weight, :decimal, default: nil, nullable: true

      def eligible?(package)
        weight = package.weight
        return false if preferred_minimum_weight.present? && weight < preferred_minimum_weight
        return false if preferred_maximum_weight.present? && weight > preferred_maximum_weight

        true
      end
    end
  end
end
