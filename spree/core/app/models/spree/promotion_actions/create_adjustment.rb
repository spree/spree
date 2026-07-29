module Spree
  module PromotionActions
    # A whole-order discount. The winning order-level amount is distributed
    # proportionally across line items at application time (largest-remainder
    # over each line's remaining discounted base) — no order-attached rows.
    class CreateAdjustment < PromotionAction
      include Spree::CalculatedAdjustments

      before_validation -> { self.calculator ||= Calculator::FlatPercentItemTotal.new }

      def self.additional_permitted_attributes
        [calculator: [:type, { preferences: {} }]]
      end

      def discount_scope
        :order
      end

      def perform(options = {})
        apply_via_adjuster(options)
      end

      def compute_amount(order)
        [order_total(order), compute(order)].min * -1
      end

      def order_total(order)
        order.item_total + order.ship_total - order.shipping_discount
      end
    end
  end
end
