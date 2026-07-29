module Spree
  module DeliveryMethodRules
    # Bounds the method by the package's item total (inclusive min/max in the
    # owner's currency). Empty preferences pass — half-configured rules fail
    # open per-rule, matching the PromotionRule/PriceRule convention.
    class ItemTotalRule < Spree::DeliveryMethodRule
      preference :minimum_amount, :decimal, default: nil, nullable: true
      preference :maximum_amount, :decimal, default: nil, nullable: true

      def eligible?(package)
        total = package.item_total
        return false if preferred_minimum_amount.present? && total < preferred_minimum_amount
        return false if preferred_maximum_amount.present? && total > preferred_maximum_amount

        true
      end
    end
  end
end
