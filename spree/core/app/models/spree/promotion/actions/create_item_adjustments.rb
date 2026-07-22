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

          # Prevent negative order totals: clamp to what other discounts left
          other_discounts = order.discount_lines.where.not(promotion_action_id: id).sum(:amount)
          amounts << order.amount + other_discounts if other_discounts.negative?

          amounts.min * -1
        end
      end
    end
  end
end
