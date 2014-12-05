module Spree
  class Promotion
    module Actions
      class FreeShipping < PromotionAction
        include Spree::AdjustmentSource

        def perform(options={})
          order = options[:order]
          order.shipments.map{ |shipment| create_adjustment(order, shipment) }.any?
        end

        def compute_amount(shipment)
          [accumulated_total(shipment), shipment.cost].min * -1
        end

      end
    end
  end
end