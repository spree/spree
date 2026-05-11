module Spree
  module Payments
    class HandleWebhook
      prepend Spree::ServiceModule::Base

      # @param payment_method [Spree::PaymentMethod] the payment method that received the webhook
      # @param action [Symbol] normalized action (:captured, :authorized, :failed, :canceled)
      # @param payment_session [Spree::PaymentSession] the payment session associated with the webhook
      # @param metadata [Hash] gateway-specific metadata (e.g. charge data, psp reference)
      def call(payment_method:, action:, payment_session:, metadata: {})
        return success(nil) if payment_session.nil?

        order = payment_session.order

        case action
        when :captured
          handle_success(payment_session, order, metadata, capture: true)
        when :authorized
          handle_success(payment_session, order, metadata, capture: false)
        when :failed
          payment_session.fail if payment_session.can_fail?
          success(payment_session)
        when :canceled
          payment_session.cancel if payment_session.can_cancel?
          success(payment_session)
        else
          failure(payment_session, "Unknown webhook action: #{action}")
        end
      end

      private

      # @param capture [Boolean] true if funds were captured (final), false for an authorization-only event.
      #   Mirrors Spree::Payment#confirm!: capture=true → complete! + capture_event, capture=false → pend!.
      def handle_success(payment_session, order, metadata, capture:)
        order.with_lock do
          # Idempotency: if the session was already completed (by the API
          # endpoint or a previous webhook), skip duplicate processing.
          if payment_session.reload.completed?
            return success(payment_session)
          end

          payment = payment_session.find_or_create_payment!(metadata)

          if payment.present? && !payment.completed?
            payment.started_processing! if payment.checkout?

            if capture
              if payment.can_complete?
                payment.complete!
                payment.capture_events.create!(amount: payment.amount)
              end
            else
              # Authorization-only: funds are on hold but not captured. Leave the
              # payment in `pending` so order.payment_state lands on `balance_due`
              # until a subsequent capture webhook (or admin capture) completes it.
              payment.pend! if payment.can_pend?
            end
          end

          payment_session.complete if payment_session.can_complete?

          unless order.reload.completed?
            Spree::Dependencies.carts_complete_service.constantize.call(cart: order)
          end
        end

        success(payment_session)
      rescue StandardError => e
        Rails.error.report(e, context: { payment_session_id: payment_session.id, order_id: order.id }, source: 'spree.payments.webhook')
        failure(payment_session, e.message)
      end
    end
  end
end
