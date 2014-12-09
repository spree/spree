module Spree
  class Promotion
    module Actions
      class CreateAdjustment < PromotionAction
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        has_many :adjustments, as: :source

        before_validation -> { self.calculator ||= Calculator::FlatPercentItemTotal.new }
        before_destroy :deals_with_adjustments_for_deleted_source

        def perform(options = {})
          order = options[:order]
          return if promotion_credit_exists?(order)
          create_adjustment(order, order)
        end

        def compute_amount(order)
          [(order.item_total + order.ship_total), compute(order)].min * -1
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

      end
    end
  end
end
