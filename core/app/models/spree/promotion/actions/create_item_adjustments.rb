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
          promotion = payload[:promotion]

          result = false

          line_items_to_adjust(promotion, order).each do |line_item|
            current_result = self.create_adjustment(line_item, order)
            result ||= current_result
          end
          return result
        end

        def create_adjustment(adjustable, order)
          self.adjustments.create!(
            adjustable: adjustable,
            order: order,
            label: "#{Spree.t(:promotion)} (#{promotion.name})",
          )
          true
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

          def line_items_to_adjust(promotion, order)
            excluded_ids = self.adjustments.
              where(adjustable_id: order.line_items.pluck(:id), adjustable_type: 'Spree::LineItem').
              pluck(:adjustable_id)

            order.line_items.where.not(id: excluded_ids).select do |line_item|
              promotion.line_item_actionable? order, line_item
            end
          end

      end
    end
  end
end
