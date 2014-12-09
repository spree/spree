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
          order = options[:order]

          amount = compute_amount(order)
          return if amount == 0
          adjustment = Spree::Adjustment.new(
            amount: amount,
            order: order,
            adjustable: order,
            source: self,
            label: "#{Spree.t(:promotion)} (#{promotion.name})"
          )
          adjustment.save
        end

        # Ensure a negative amount which does not exceed the sum of the order's
        # item_total and ship_total
        def compute_amount(calculable)
          amount = self.calculator.compute(calculable).to_f.abs
          [(calculable.item_total + calculable.ship_total), amount].min * -1
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
