module Spree
  module Payments
    class HandleWebhookJob < Spree::BaseJob
      queue_as Spree.queues.payment_webhooks

      def perform(payment_method_id:, action:, payment_session_id:)
        payment_method = Spree::PaymentMethod.find(payment_method_id)
        payment_session = Spree::PaymentSession.find(payment_session_id)

        Spree::Dependencies.payments_handle_webhook_service.constantize.call(
          payment_method: payment_method,
          action: action.to_sym,
          payment_session: payment_session
        )
      end
    end
  end
end
