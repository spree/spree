module Spree
  class Promotion
    module Actions
      class CreateItemAdjustments < PromotionAction
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        has_many :adjustments, as: :source

        delegate :eligible?, to: :promotion

        before_validation :ensure_action_has_calculator
        before_destroy :deals_with_adjustments_for_deleted_source

        def perform(payload = {})
          order = payload[:order]

          # Find only the line items which have not already been adjusted by this promotion
          adjusted_line_item_ids = order.all_adjustments.source(self).line_item.pluck(:adjustable_id)

          unadjusted_line_items = order.line_items.reject do |line_item|
            adjusted_line_item_ids.include?(line_item.id)
          end

          unadjusted_line_items.map do |line_item|
            create_adjustment(line_item, order) if promotion.line_item_actionable?(order, line_item)
          end.any?
        end

        # Ensure a negative amount which does not exceed the sum of the order's
        # item_total and ship_total
        def compute_amount(adjustable)
          order = adjustable.is_a?(Order) ? adjustable : adjustable.order
          return 0 unless promotion.line_item_actionable?(order, adjustable)
          promotion_amount = self.calculator.compute(adjustable).to_f.abs

          [adjustable.amount, promotion_amount].min * -1
        end

        private

        def create_adjustment(adjustable, order)
          amount = self.compute_amount(adjustable)
          return if amount == 0

          order.create_adjustment!(
            amount:     amount,
            source:     self,
            adjustable: adjustable,
            label:      "#{Spree.t(:promotion)} (#{promotion.name})",
          )
          true
        end

        def ensure_action_has_calculator
          return if self.calculator
          self.calculator = Calculator::PercentOnLineItem.new
        end

      end
    end
  end
end
