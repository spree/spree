module Spree
  class Promotion
    module Actions
      class CreateItemAdjustments < PromotionAction
        include Spree::Core::CalculatedAdjustments
        include Spree::Core::AdjustmentSource

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
            create_adjustment(line_item, order)
          end.any?
        end

        def create_adjustment(adjustable, order)
          amount = self.compute_amount(adjustable)
          return if amount == 0
          return if promotion.product_ids.present? and !promotion.product_ids.include?(adjustable.product.id)
          order.create_adjustment!(
            amount:     amount,
            source:     self,
            adjustable: adjustable,
            label:      "#{Spree.t(:promotion)} (#{promotion.name})",
          )
          true
        end

        # Ensure a negative amount which does not exceed the sum of the order's
        # item_total and ship_total
        def compute_amount(adjustable)
          promotion_amount = self.calculator.compute(adjustable).to_f.abs

          [adjustable.amount, promotion_amount].min * -1
        end

        private
          # Tells us if there if the specified promotion is already associated with the line item
          # regardless of whether or not its currently eligible. Useful because generally
          # you would only want a promotion action to apply to line item no more than once.
          #
          # Receives an adjustment +source+ (here a PromotionAction object) and tells
          # if the order has adjustments from that already
          def promotion_credit_exists?(adjustable)
            self.adjustments.where(:adjustable_id => adjustable.id).exists?
          end

          def ensure_action_has_calculator
            return if self.calculator
            self.calculator = Calculator::PercentOnLineItem.new
          end

      end
    end
  end
end
