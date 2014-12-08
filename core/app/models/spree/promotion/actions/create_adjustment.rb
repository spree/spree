module Spree
  class Promotion
    module Actions
      class CreateAdjustment < PromotionAction
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        before_validation -> { self.calculator ||= Calculator::FlatPercentItemTotal.new }

        def perform(opts={})
          create_adjustment(opts[:order], opts[:order])
        end

        def compute_amount(order)
          [accumulated_total(order), compute(order)].min * -1
        end

      end
    end
  end
end
