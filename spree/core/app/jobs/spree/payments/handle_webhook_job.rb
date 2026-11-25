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

      # Reported, not raised: the payment is settled on the cart, but the cart
      # cannot become an order — see DETERMINISTIC_FAILURE_CODES.
      class CompletionBlocked < StandardError; end

      # Failures of Spree::Carts::Complete that no retry can change. The cart
      # fails a checkout requirement (emptied, no delivery method selected),
      # lost a batch coupon code it was priced with, or its tax engine
      # refused the sale — and a cart a gateway took
      # money for is fenced (Spree::Cart#payment_session_settled?), so nobody
      # can change it into one that completes. Retrying only repeats the
      # failure; the payment stays recorded on the cart and the failure is
      # reported once for staff to resolve.
      DETERMINISTIC_FAILURE_CODES = %w[validation_failed coupon_code_unavailable tax_calculation_refused].freeze

      retry_on SettlementFailed, wait: :polynomially_longer, attempts: 5

      # metadata defaults to {} so jobs enqueued before it was passed still run.
      def perform(payment_method_id:, action:, payment_session_id:, metadata: {})
        payment_method = Spree::PaymentMethod.find(payment_method_id)
        Spree::Current.store = payment_method.store
        payment_session = Spree::PaymentSession.find(payment_session_id)

        result = Spree.payments_handle_webhook_workflow.call(
          payment_method: payment_method,
          action: action.to_sym,
          payment_session: payment_session,
          metadata: metadata
        )
        return unless result&.failure?
        return report_blocked_completion(payment_session, result) if completion_blocked?(result)

        raise SettlementFailed, "Payment session #{payment_session.id}: #{result.error}"
      end

      private

      def completion_blocked?(result)
        result.error.code.in?(DETERMINISTIC_FAILURE_CODES)
      end

      # Charged without an order is the outcome to make loud: reported as an
      # unhandled error so the error tracker alerts on it, with what staff
      # need to find the money (the payment session's gateway reference) and
      # why the cart could not complete.
      def report_blocked_completion(payment_session, result)
        code = result.error.code
        failure = result.error.value.is_a?(Hash) ? result.error.value : {}
        error = CompletionBlocked.new(
          "Payment session #{payment_session.id} settled, but its #{payment_session.cart_id ? 'cart' : 'order'} " \
          "cannot be completed (#{code}); the buyer was charged without an order"
        )

        Rails.error.report(
          error,
          handled: false,
          severity: :error,
          context: {
            payment_session_id: payment_session.id,
            payment_session_external_id: payment_session.external_id,
            payment_id: payment_session.payment&.id,
            cart_id: payment_session.cart_id,
            order_id: payment_session.order_id,
            code: code,
            errors: failure[:errors] || failure[:message]
          }.compact,
          source: 'spree.payments.webhook'
        )
      end
    end
  end
end
