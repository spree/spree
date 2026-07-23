module Spree
  class Promotion
    module Actions
      class CreateItemAdjustments < PromotionAction
        include Spree::CalculatedAdjustments

        before_validation -> { self.calculator ||= Calculator::PercentOnLineItem.new }

        def self.additional_permitted_attributes
          [calculator: [:type, { preferences: {} }]]
        end

        # Writes candidate discount lines per actionable line item;
        # best-promo selection happens in Adjusters::Promotion.
        def perform(options = {})
          order     = options[:order]
          promotion = options[:promotion]

          results = order.line_items.map do |line_item|
            next false unless promotion.line_item_actionable?(order, line_item)

            upsert_discount_line(order, line_item, compute_amount(line_item))
          end

          results.include?(true)
        end

        def compute_amount(line_item)
          return 0 unless promotion.line_item_actionable?(line_item.order, line_item)

          amounts = [line_item.amount, compute(line_item)]
          order   = line_item.order

          # Prevent negative order totals: clamp to what the whole-order
          # discounts left of the item value (fulfillment discounts like free
          # shipping never reduce it — same scope as the legacy order-level
          # eligible adjustments)
          order_level_discounts = order.discount_lines.select { |line| line.promotion? && line.promotion_action.order_level? }.sum(&:amount)
          amounts << order.amount + order_level_discounts if order_level_discounts.negative?

          amounts.min * -1
        end
      end
    end
  end
end
