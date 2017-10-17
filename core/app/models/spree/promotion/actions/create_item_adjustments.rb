module Spree
  class Promotion
    module Actions
      class CreateItemAdjustments < PromotionAction
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        before_validation -> { self.calculator ||= Calculator::PercentOnLineItem.new }

        def perform(options = {})
          order = options[:order]
          promotion = options[:promotion]
          promotion_code = options[:promotion_code]
          create_unique_adjustments(order, order.line_items, promotion_code) do |line_item|
            promotion.line_item_actionable?(order, line_item)
          end
        end

        def compute_amount(line_item)
          return 0 unless promotion.line_item_actionable?(line_item.order, line_item)
          [line_item.amount, compute(line_item)].min * -1
        end
      end
    end
  end
end
