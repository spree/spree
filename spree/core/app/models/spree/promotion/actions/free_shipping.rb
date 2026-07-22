module Spree
  class Promotion
    module Actions
      class FreeShipping < Spree::PromotionAction
        def perform(payload = {})
          order = payload[:order]
          return false if order.shipments.empty?

          order.shipments.each do |shipment|
            upsert_discount_line(order, shipment, compute_amount(shipment))
          end

          # The promotion counts as activated (order join + coupon
          # registration) even when shipping currently costs 0 — the discount
          # line materializes once a paid delivery rate is selected.
          true
        end

        def compute_amount(shipment)
          shipment.cost * -1
        end
      end
    end
  end
end
