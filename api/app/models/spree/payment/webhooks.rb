module Spree
  class Payment < Spree.base_class
    module Webhooks
      extend ActiveSupport::Concern
      include Spree::Webhooks::HasWebhooks

      class_methods do
        def custom_webhook_events
          %w[payment.paid payment.voided]
        end
      end

      def send_payment_voided_webhook
        queue_webhooks_requests!('payment.voided')
      end

      def send_payment_completed_webhook
        queue_webhooks_requests!('payment.paid')
        order.queue_webhooks_requests!('order.paid') if order.paid?
      end
    end
  end
end
