module Spree
  class Promotion
    module Actions
      class FreeShipping < Spree::PromotionAction
        include Spree::AdjustmentSource

        def perform(payload = {})
          order = payload[:order]
          promotion_code = payload[:promotion_code]
          create_unique_adjustments(order, order.shipments, promotion_code)
        end

        def compute_amount(shipment)
          shipment.cost * -1
        end
      end
    end
  end
end
