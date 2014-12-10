module Spree
  class Promotion
    module Actions
      class FreeShipping < Spree::PromotionAction
        include Spree::AdjustmentSource

        def perform(payload={})
          order = payload[:order]
          results = order.shipments.map do |shipment|
            adjustment = shipment.adjustments.new(
              order: shipment.order, 
              amount: compute_amount(shipment),
              source: self,
              label: label,
            )
            adjustment.save
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
      end
    end
  end
end