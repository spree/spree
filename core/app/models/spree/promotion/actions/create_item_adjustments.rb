module Spree
  class Promotion
    module Actions
      class CreateItemAdjustments < PromotionAction
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        before_validation -> { self.calculator ||= Calculator::PercentOnLineItem.new }

        def perform(options={})
          order, promotion = options[:order], options[:promotion]
          already_adjusted = adjustments.where(order: order).pluck(:adjustable_id)

          order.line_items.where.not(id: already_adjusted).map do |line_item|
            next unless promotion.line_item_actionable?(order, line_item)
            create_adjustment(order, line_item)
          end.any?
        end

        def compute_amount(line_item)
          return 0 unless promotion.line_item_actionable?(line_item.order, line_item)
          [accumulated_total(line_item), compute(line_item)].min * -1
        end

      end
    end
  end
end
