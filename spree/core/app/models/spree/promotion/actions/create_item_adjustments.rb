module Spree
  class Promotion
    module Actions
      # Writes per-line-item promotion Discount rows (winner-only competition
      # handled by Spree::Adjusters::Promotion on every recalculation).
      class CreateItemAdjustments < PromotionAction
        include Spree::CalculatedAdjustments

        before_validation -> { self.calculator ||= Calculator::PercentOnLineItem.new }

        self.additional_permitted_attributes = [calculator: [:type, { preferences: {} }]]

        def discount_scope
          :line_item
        end

        def perform(options = {})
          apply_via_adjuster(options)
        end

        # Negative-total protection is the adjuster's job: every discount row is
        # clamped against its line's remaining discounted base, so the order net
        # can never go below zero.
        def compute_amount(line_item)
          return 0 unless promotion.line_item_actionable?(line_item.order, line_item)

          [line_item.amount, compute(line_item)].min * -1
        end
      end
    end
  end
end
