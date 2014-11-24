module Spree
  class Promotion
    module Actions
      class CreateAdjustment < PromotionAction
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        has_many :adjustments, as: :source
        before_validation -> { self.calculator ||= Calculator::FlatPercentItemTotal.new }

        def perform(options = {})
          order = options[:order]
          adjustment = order.adjustments.new(order: order, source: self, label: label)
          adjustment.save
        end

        def compute_amount(order)
          @order = order
          @amount = compute(order)
          amount_must_not_exceed_available_amount
          update_available_amount
          amount * -1
        end

      end
    end
  end
end
