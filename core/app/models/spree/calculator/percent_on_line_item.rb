module Spree
  class Calculator
    class PercentOnLineItem < Calculator
      preference :percent, :decimal, default: 0
      preference :apply_only_on_full_priced_items, :boolean, default: false

      def self.description
        Spree.t(:percent_per_item)
      end

      def compute(object)
        return 0 if preferred_apply_only_on_full_priced_items && object.variant.compare_at_amount_in(object.currency).present?

        computed_amount = (object.amount * preferred_percent / 100).round(2)

        # We don't want to cause the promotion adjustments to push the order into a negative total.
        if computed_amount > object.amount
          object.amount
        else
          computed_amount
        end
      end
    end
  end
end
