module Spree
  module PromotionActions
    # Writes a fulfillment-attached Discount covering the fulfillment cost.
    # The row persists even at zero amount — Order#has_free_shipping? tests
    # row existence.
    class FreeShipping < Spree::PromotionAction
      def discount_scope
        :fulfillment
      end

      def persist_at_zero?
        true
      end

      def perform(options = {})
        apply_via_adjuster(options)
      end

      def compute_amount(fulfillment)
        fulfillment.cost * -1
      end
    end
  end
end
