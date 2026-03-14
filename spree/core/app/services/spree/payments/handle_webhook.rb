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
        when :captured, :authorized
          handle_success(payment_session, order, metadata)
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

      def handle_success(payment_session, order, metadata)
        order.with_lock do
          # Ensure payment record exists
          payment = payment_session.find_or_create_payment!(metadata)

          # Mark payment as completed — the webhook confirms the gateway processed it
          if payment.present? && !payment.completed?
            payment.started_processing! if payment.checkout?
            payment.complete! if payment.can_complete?
          end

          # Mark session as completed
          payment_session.complete if payment_session.can_complete?

          # Complete order if not already done
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
