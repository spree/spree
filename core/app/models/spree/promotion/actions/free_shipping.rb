module Spree
  class Promotion
    module Actions
      class FreeShipping < Spree::PromotionAction

        def perform(payload={})
          order = payload[:order]
          order.shipments.map do |shipment|
            next if promotion_credit_exists?(shipment)
            create_adjustment(order, shipment, compute_amount(shipment))
          end.any?
        end

        def compute_amount(shipment)
          shipment.cost * -1
        end

        private

        def promotion_credit_exists?(shipment)
          shipment.adjustments.where(:source_id => self.id).exists?
        end
      end
    end
  end
end