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
          def initialize(order, excluded_amount, excluded_quantity: 0)
            super(order)
            @excluded_amount = excluded_amount
            @excluded_quantity = excluded_quantity
          end

          def amount
            [__getobj__.amount - @excluded_amount, BigDecimal(0)].max
          end

          def quantity
            [__getobj__.quantity - @excluded_quantity, 0].max
          end

          # Calculators dispatch on the class (`compute_order`) and may type-check it.
          delegate :class, :is_a?, :kind_of?, :instance_of?, to: :__getobj__
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
          excluded_line_items, discountable_line_items = order.line_items.partition do |line_item|
            promotion.excludes_line_item?(line_item)
          end
          computable = if excluded_line_items.empty?
                         order
                       else
                         # +order.amount+ already leaves out gift units.
                         excluded_amount = excluded_line_items.sum(BigDecimal(0), &:amount) - order.gift_amount(among: excluded_line_items)
                         DiscountableOrder.new(order, excluded_amount, excluded_quantity: excluded_line_items.sum(&:quantity))
                       end

          # Capped at what it can land on: the discount is shared over the
          # discountable lines only, never delivery.
          [discountable_line_items.sum(BigDecimal(0), &:amount), compute(computable)].min * -1
        end

        def order_total(order)
          order.item_total + order.delivery_total - order.fulfillment_discount
        end
      end
    end
  end
end
