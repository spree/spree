module Spree
  class Promotion
    module Actions
      class CreateItemAdjustment < PromotionAction
        include Spree::Core::CalculatedAdjustments

        has_many :adjustments, as: :source

        delegate :eligible?, to: :promotion

        before_validation :ensure_action_has_calculator
        before_destroy :deals_with_adjustments

        def perform(payload = {})
          line_item = payload[:line_item]
          unless promotion_credit_exists?(line_item)
            self.create_adjustment(line_item)
          end
        end

        def create_adjustment(adjustable)
          amount = self.compute_amount(adjustable)
          self.adjustments.create!(
            amount: amount,
            adjustable: adjustable,
            order: adjustable.order,
            label: "#{Spree.t(:promotion)} (#{promotion.name})",
          )
        end

        # Ensure a negative amount which does not exceed the sum of the order's
        # item_total and ship_total
        def compute_amount(adjustable)
          amount = self.calculator.compute(adjustable).to_f.abs
          [adjustable.total, amount].min * -1
        end

        private
          # Tells us if there if the specified promotion is already associated with the line item
          # regardless of whether or not its currently eligible. Useful because generally
          # you would only want a promotion action to apply to order no more than once.
          #
          # Receives an adjustment +source+ (here a PromotionAction object) and tells
          # if the order has adjustments from that already
          def promotion_credit_exists?(adjustable)
            self.adjustments.where(:adjustable_id => adjustable.id).exists?
          end

          def ensure_action_has_calculator
            return if self.calculator
            self.calculator = Calculator::FlatPercentItemTotal.new
          end

          def deals_with_adjustments
            adjustment_scope = Adjustment.includes(:order).references(:spree_orders)
            # For incomplete orders, remove the adjustment completely.
            adjustment_scope.where("spree_orders.completed_at IS NULL").each do |adjustment|
              adjustment.destroy
            end

            # For complete orders, the source will be invalid.
            # Therefore we nullify the source_id, leaving the adjustment in place.
            # This would mean that the order's total is not altered at all.
            adjustment_scope.where("spree_orders.completed_at IS NOT NULL").each do |adjustment|
              adjustment.update_column(:source_id, nil)
            end
          end
      end
    end
  end
end
