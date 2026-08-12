module Spree
  module Payments
    # Processes a normalized gateway webhook.
    #
    # In the workflow tier because it is the gateway's asynchronous entry
    # point into checkout: a duplicate delivery must not create a second
    # payment or complete an order twice, and integrations need somewhere to
    # observe a settled session without monkey-patching the service.
    class HandleWebhook < Spree::Workflow
      hooks :after_handle

      # The payment created or found for the session — nil for terminal
      # actions (failed, canceled) and for replayed deliveries.
      attr_reader :payment

      # @param payment_method [Spree::PaymentMethod] the method that received the webhook
      # @param action [Symbol] normalized action (:captured, :authorized, :failed, :canceled)
      # @param payment_session [Spree::PaymentSession, nil] nil is a no-op —
      #   webhooks arrive for sessions this store does not own
      # @param metadata [Hash] gateway-specific payload (charge data, psp reference)
      def perform(payment_method:, action:, payment_session:, metadata: {})
        super

        halt!(nil) if payment_session.nil?

        case action
        when :captured, :authorized then step :settle_session
        when :failed then step :fail_session
        when :canceled then step :cancel_session
        else failure(payment_session, "Unknown webhook action: #{action}")
        end

        run_hooks :after_handle
        success(payment_session)
      end

      private

      def order
        @order ||= payment_session.owner
      end

      # Locked because a gateway may deliver the same event more than once,
      # and the redelivery races the checkout request that created the
      # session.
      def settle_session
        # Provider round trips happen here, before the lock — settlement
        # inside it must be pure database work.
        payment_session.prepare_for_settlement!

        order.with_lock do
          # Idempotency: the API endpoint or an earlier delivery may have
          # already settled this session. Not halt! — that is forbidden
          # inside a transaction (there is nothing committed to halt with).
          next if payment_session.reload.completed?

          step :ensure_payment
          step :complete_session
          step :complete_owner unless order.reload.completed?
        end
      rescue Spree::Workflow::FailureSignal
        raise
      rescue StandardError => error
        Rails.error.report(
          error,
          context: { payment_session_id: payment_session.id, order_id: order.id },
          source: 'spree.payments.webhook'
        )
        failure(payment_session, error.message)
      end

      # :captured means the gateway reports the funds as moved, so the payment
      # completes with a capture event; :authorized pends it (auth-only,
      # payment_state=balance_due) until an explicit capture. The webhook's
      # action decides, not the method's capture timing.
      def ensure_payment
        @payment = payment_session.settle_payment!(captured: action == :captured, metadata: metadata)
      end

      def complete_session
        payment_session.complete if payment_session.can_complete?
      end

      def complete_owner
        completable = order.is_a?(Spree::Order) ? (order.cart || order) : order
        Spree.carts_complete_workflow.call(cart: completable)
      end

      def fail_session
        payment_session.fail if payment_session.can_fail?
      end

      def cancel_session
        payment_session.cancel if payment_session.can_cancel?
      end
    end
  end
end
