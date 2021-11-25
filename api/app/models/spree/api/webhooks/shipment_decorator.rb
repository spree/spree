module Spree
  module Api
    module Webhooks
      module ShipmentDecorator
        def self.prepended(base)
          def base.custom_webhook_events
            %w[shipment.shipped]
          end
        end

        def after_ship
          super
          queue_webhooks_requests!('shipment.shipped')
          order.queue_webhooks_requests!('order.shipped') if order.fully_shipped?
        end
      end
    end
  end
end

Spree::Shipment.prepend(Spree::Api::Webhooks::ShipmentDecorator)
