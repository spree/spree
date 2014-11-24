module Spree
  class Promotion
    module Actions
      class CreateAdjustment < PromotionAction
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        has_many :adjustments, as: :source

        delegate :eligible?, to: :promotion

        before_validation :ensure_action_has_calculator
        before_destroy :deals_with_adjustments_for_deleted_source

        # Creates the adjustment related to a promotion for the order passed
        # through options hash
        #
        # Returns `true` if an adjustment is applied to an order,
        # `false` if the promotion has already been applied.
        def perform(options = {})
          adjustment = Spree::Adjustment.new(
            order: options[:order],
            adjustable: options[:order],
            source: self,
            label: "#{Spree.t(:promotion)} (#{promotion.name})"
          )
          adjustment.save
        end

        # Ensure a negative amount which does not exceed the sum of the order's
        # item_total and ship_total
        def compute_amount(order)
          amount = self.calculator.compute(order).to_f
          amount = [order.item_total + order.ship_total - order.adjustment_total, amount].min * -1
          order.adjustment_total -= amount
          amount
        end

        private

          def ensure_action_has_calculator
            return if self.calculator
            self.calculator = Calculator::FlatPercentItemTotal.new
          end

      end
    end
  end
end
