module Spree
  module Payments
    class HandleWebhookJob < Spree::BaseJob
      queue_as Spree.queues.payment_webhooks

      retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
      retry_on ActiveRecord::LockWaitTimeout, wait: 5.seconds, attempts: 3
      discard_on ActiveRecord::RecordNotFound

      # The gateway got its 200 when this job was enqueued and will not send
      # the webhook again, so a failed settlement (a gateway 5xx, a lock
      # timeout swallowed by the workflow) must be retried here or the
      # buyer is charged without an order. Safe to replay: the workflow
      # skips a payment that is already completed.
      class SettlementFailed < StandardError; end

      retry_on SettlementFailed, wait: :polynomially_longer, attempts: 5

      def perform(payment_method_id:, action:, payment_session_id:)
        payment_method = Spree::PaymentMethod.find(payment_method_id)
        Spree::Current.store = payment_method.store
        payment_session = Spree::PaymentSession.find(payment_session_id)

        result = Spree.payments_handle_webhook_workflow.call(
          payment_method: payment_method,
          action: action.to_sym,
          payment_session: payment_session
        )

        raise SettlementFailed, "Payment session #{payment_session.id}: #{result.error}" if result&.failure?
      end
    end
  end
end
