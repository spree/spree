module Spree
  class Order < Spree.base_class
    module Webhooks
      extend ActiveSupport::Concern
      include Spree::Webhooks::HasWebhooks

      included do
        after_update_commit :queue_webhooks_requests_for_order_resumed!
      end

      class_methods do
        def custom_webhook_events
          %w[order.canceled order.placed order.resumed order.shipped]
        end
      end

      def send_order_canceled_webhook
        queue_webhooks_requests!('order.canceled')
      end

      def send_order_placed_webhook
        queue_webhooks_requests!('order.placed')
      end

      def send_order_resumed_webhook
        queue_webhooks_requests!('order.resumed')
        self.state_machine_resumed = false # to not fire the same webhook twice
      end

      def queue_webhooks_requests_for_order_resumed!
        return if state_machine_resumed?
        return unless state_previously_changed?
        return unless state_previous_change&.last == 'resumed'

        send_order_resumed_webhook
      end
    end
  end
end
