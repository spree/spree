# frozen_string_literal: true

module Spree
  module CommissionRules
    # Charge this rate only on sales within a value band — "15% under 50, 10%
    # above" is two rates, each holding one of these.
    #
    # The band is compared against what the commission would be charged on:
    # the line's own discounted value, so a rule reads the same money the fee
    # does. Bounds are inclusive at the bottom and exclusive at the top, which
    # is what lets two bands meet at a number without overlapping or leaving
    # it uncovered.
    #
    # This rule is the reason commission rules became classes. It could not
    # exist while a rule was only able to name a record.
    class ItemTotalRule < Spree::CommissionRule
      preference :min_amount, :decimal, nullable: true
      preference :max_amount, :decimal, nullable: true

      def applicable?(context)
        amount = context.commission_basis
        return false if amount.nil?
        return false if preferred_min_amount.present? && amount < preferred_min_amount
        return false if preferred_max_amount.present? && amount >= preferred_max_amount

        true
      end
    end
  end
end
