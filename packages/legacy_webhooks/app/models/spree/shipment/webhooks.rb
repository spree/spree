module Spree
  class Shipment < Spree.base_class
    module Webhooks
      extend ActiveSupport::Concern
      include Spree::Webhooks::HasWebhooks

      class_methods do
        def custom_webhook_events
          %w[shipment.shipped]
        end
      end

      def send_shipment_shipped_webhook
        queue_webhooks_requests!('shipment.shipped')
        order.queue_webhooks_requests!('order.shipped') if order.fully_shipped?
      end
    end
  end
end
