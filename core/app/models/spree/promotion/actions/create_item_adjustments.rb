module Spree
  class Promotion
    module Actions
      class CreateItemAdjustments < PromotionAction
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        has_many :adjustments, as: :source

        before_validation -> { self.calculator ||= Calculator::PercentOnLineItem.new }
        before_destroy :deals_with_adjustments_for_deleted_source

        def perform(options={})
          order, promotion = options[:order], options[:promotion]
          already_adjusted = adjustments.where(order: order).pluck(:adjustable_id)

          order.line_items.where.not(id: already_adjusted).map do |line_item|
            next unless promotion.line_item_actionable?(order, line_item)

            amount = compute_amount(line_item)
            next if amount == 0

            create_adjustment(order, line_item, amount)
          end.any?
        end

        def compute_amount(line_item)
          return 0 unless promotion.line_item_actionable?(line_item.order, line_item)
          [line_item.amount, compute(line_item)].min * -1
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

      end
    end
  end
end
