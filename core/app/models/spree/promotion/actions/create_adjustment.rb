module Spree
  class Promotion
    module Actions
      class CreateAdjustment < PromotionAction
        include Spree::AdjustmentSource

        has_one :calculator, class_name: 'Spree::Calculator', as: :calculable, inverse_of: :calculable, dependent: :destroy, autosave: true
        accepts_nested_attributes_for :calculator
        validates :calculator, presence: true

        before_validation -> { self.calculator ||= Calculator::FlatPercentItemTotal.new }

        def perform(options = {})
          order = options[:order]
          create_unique_adjustment(order, order)
        end

        def compute_amount(order)
          [(order.item_total + order.ship_total - order.shipping_discount), calculator.compute(order)].min * -1
        end
      end
    end
  end
end
