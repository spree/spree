module Spree
  class Promotion
    module Actions
      class CreateAdjustment < PromotionAction
        include Spree::Core::CalculatedAdjustments

        has_many :adjustments, as: :source

        delegate :eligible?, to: :promotion

        before_validation :ensure_action_has_calculator
        before_destroy :deals_with_adjustments

        # Creates the adjustment related to a promotion for the order passed
        # through options hash
        #
        # Returns `true` if an adjustment is applied to an order,
        # `false` if the promotion has already been applied.
        def perform(options = {})
          order = options[:order]
          return if promotion_credit_exists?(order)

          amount = compute_amount(order)
          return if amount == 0
          Spree::Adjustment.create!(
            amount: amount,
            order: order,
            adjustable: order,
            source: self,
            label: "#{Spree.t(:promotion)} (#{promotion.name})"
          )
          true
        end

        # Ensure a negative amount which does not exceed the sum of the order's
        # item_total and ship_total
        def compute_amount(calculable)
          amount = self.calculator.compute(calculable).to_f.abs
          [(calculable.item_total + calculable.ship_total), amount].min * -1
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
            adjustment_scope = self.adjustments.joins("LEFT OUTER JOIN spree_orders ON spree_orders.id = spree_adjustments.adjustable_id")
            # For incomplete orders, remove the adjustment completely.
            adjustment_scope.where("spree_orders.completed_at IS NULL").readonly(false).destroy_all

            # For complete orders, the source will be invalid.
            # Therefore we nullify the source_id, leaving the adjustment in place.
            # This would mean that the order's total is not altered at all.
            adjustment_scope.where("spree_orders.completed_at IS NOT NULL").update_all("source_id = NULL")
          end
      end
    end
  end
end
