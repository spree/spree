module Spree
  class Promotion
    module Actions
      class FreeShipping < Spree::PromotionAction
        def perform(payload={})
          order = payload[:order]
          order.shipments.each do |shipment|
            return false if promotion_credit_exists?(shipment)
            order.create_adjustment!(
              adjustable: shipment,
              amount:     compute_amount(shipment),
              source:     self,
              label:      label
            )
          end
          true
        end

        def label
          "#{Spree.t(:promotion)} (#{promotion.name})"
        end

        def compute_amount(shipment)
          shipment.cost * -1
        end

        private

        def promotion_credit_exists?(shipment)
          shipment.adjustments.source(self).exists?
        end
      end
    end
  end
end
