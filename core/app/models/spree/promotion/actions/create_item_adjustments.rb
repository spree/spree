module Spree
  class Promotion
    module Actions
      class CreateItemAdjustments < PromotionAction
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        has_many :adjustments, as: :source

        before_validation -> { self.calculator ||= Calculator::PercentOnLineItem.new }
        before_destroy :deals_with_adjustments_for_deleted_source

        def perform(options = {})
          order, promotion = options[:order], options[:promotion]

          line_items_to_adjust(promotion, order).map do |line_item|
            create_adjustment(order, line_item)
          end.any?
        end

        def compute_amount(adjustable)
          return 0 unless promotion.line_item_actionable?(adjustable.order, adjustable)
          [adjustable.amount, compute(adjustable)].min * -1
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

          def line_items_to_adjust(promotion, order)
            excluded_ids = self.adjustments.
              where(adjustable_id: order.line_items.map(&:id), adjustable_type: 'Spree::LineItem').
              pluck(:adjustable_id)

            order.line_items.select do |line_item|
              !excluded_ids.include?(line_item.id) &&
                promotion.line_item_actionable?(order, line_item)
            end
          end
      end
    end
  end
end
