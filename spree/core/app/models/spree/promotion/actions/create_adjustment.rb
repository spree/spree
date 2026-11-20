module Spree
  class Promotion
    module Actions
      # A whole-order discount. The winning order-level amount is distributed
      # proportionally across line items at application time (largest-remainder
      # over each line's remaining discounted base) — no order-attached rows.
      # Lines an exclusion rule keeps the promotion off neither count towards
      # the discount nor receive a share of it.
      class CreateAdjustment < PromotionAction
        # The order as calculators see it, less the excluded lines.
        class DiscountableOrder < SimpleDelegator
          def initialize(order, excluded_amount)
            super(order)
            @excluded_amount = excluded_amount
          end

          def amount
            [__getobj__.amount - @excluded_amount, BigDecimal(0)].max
          end
        end

        include Spree::CalculatedAdjustments

        before_validation -> { self.calculator ||= Calculator::FlatPercentItemTotal.new }

        self.additional_permitted_attributes = [calculator: [:type, { preferences: {} }]]

        def discount_scope
          :order
        end

        def perform(options = {})
          apply_via_adjuster(options)
        end

        def compute_amount(order)
          excluded = excluded_amount(order)
          computable = excluded.zero? ? order : DiscountableOrder.new(order, excluded)

          [order_total(order) - excluded, compute(computable)].min * -1
        end

        def order_total(order)
          order.item_total + order.delivery_total - order.fulfillment_discount
        end

        private

        def excluded_amount(order)
          (order.line_items - promotion.discountable_line_items(order)).sum(BigDecimal(0), &:amount)
        end
      end
    end
  end
end
