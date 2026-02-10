module Spree
  class Promotion
    module Actions
      class FreeShipping < Spree::PromotionAction
        include Spree::AdjustmentSource

        def perform(payload = {})
          order = payload[:order]

          create_unique_adjustments(order, order.shipments)
        end

        def compute_amount(shipment)
          shipment.cost * -1
        end

        # we need to persist 0 amount adjustment
        def create_adjustment(order, adjustable, included = false)
          amount = compute_amount(adjustable)

          adjustable.adjustments.new(
            amount: amount,
            included: included,
            label: label,
            order: order,
            source: self
          ).save
        end
      end
    end
  end
end
