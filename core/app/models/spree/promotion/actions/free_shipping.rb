module Spree
  class Promotion
    module Actions
      class FreeShipping < Spree::PromotionAction
        def perform(payload={})
          order = payload[:order]
          results = order.shipments.map do |shipment|
            return true if promotion_credit_exists?(shipment)

            shipment.adjustments.build(
              order: shipment.order, 
              amount: compute_amount(shipment),
              source: self,
              label: label,
            )
            true
          end
          # Did we actually end up applying any adjustments?
          # If so, then this action should be classed as 'successful'
          results.any? { |r| r == true }
        end

        def label
          "#{Spree.t(:promotion)} (#{promotion.name})"
        end

        def compute_amount(shipment)
          shipment.cost * -1
        end

        private

        def promotion_credit_exists?(shipment)
          shipment.adjustments.any? do |adjustment|
            adjustment.source == self
          end
        end
      end
    end
  end
end