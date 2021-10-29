module Spree
  module Api
    module Webhooks
      module ShipmentDecorator
        def after_ship
          super
          queue_webhooks_requests!('shipment.shipped')
          order.queue_webhooks_requests!('order.shipped') if all_order_shipments_were_shipped?
        end

        private

        def all_order_shipments_were_shipped?
          order.shipments.shipped.size == order.shipments.size
        end
      end
    end
  end
end

Spree::Shipment.prepend(Spree::Api::Webhooks::ShipmentDecorator)
