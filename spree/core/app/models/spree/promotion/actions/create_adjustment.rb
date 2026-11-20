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

          # Calculators dispatch on the class (`compute_order`) and may type-check it.
          delegate :class, :is_a?, :kind_of?, to: :__getobj__
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

          [(order_total(order) - excluded).clamp(BigDecimal(0)..), compute(computable)].min * -1
        end

        def order_total(order)
          order.item_total + order.delivery_total - order.fulfillment_discount
        end

        private

        # What the excluded lines add to +order.amount+: their gift units are
        # already left out of it.
        def excluded_amount(order)
          excluded_line_items = order.line_items.select { |line_item| promotion.excludes_line_item?(line_item) }
          return BigDecimal(0) if excluded_line_items.empty?

          excluded_line_items.sum(BigDecimal(0), &:amount) - order.gift_amount(among: excluded_line_items)
        end
      end
    end
  end
end
