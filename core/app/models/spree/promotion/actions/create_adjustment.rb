module Spree
  class Promotion
    module Actions
      # Responsible for the creation and management of an adjustment since an
      # an adjustment uses its originator to also update its eligiblity and amount
      class CreateAdjustment < PromotionAction
        include Spree::Core::CalculatedAdjustments

        has_many :adjustments, as: :originator

        delegate :eligible?, to: :promotion

        before_validation :ensure_action_has_calculator
        before_destroy :deals_with_adjustments

        # Creates the adjustment related to a promotion for the order passed
        # through options hash
        def perform(options = {})
          order = options[:order]
          return if order.promotion_credit_exists?(self)

          order.line_items.each do |line_item|
            amount = self.calculator.compute(line_item)
            order.adjustments.create(
              amount: amount,
              adjustable: line_item,
              source: self,
              label: "#{Spree.t(:promotion)} (#{promotion.name})",
            )
          end
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

          def deals_with_adjustments
            Adjustment.promotion.where(:source_id => self.id).each do |adjustment|
              if adjustment.adjustable.complete?
                adjustment.update_column(:source_id, nil)
              else
                adjustment.destroy
              end
            end
          end
      end
    end
  end
end
