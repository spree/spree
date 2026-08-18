module Spree
  module PaymentSessions
    # Completes a payment session when the customer returns from the gateway —
    # the synchronous twin of Spree::Payments::HandleWebhook, which settles the
    # same session when the gateway reports out of band. Either can arrive
    # first; both settle through PaymentSession#settle_payment!.
    #
    # In the workflow tier because completion is network I/O (the gateway
    # verifies the session before settling), and because this is the one
    # moment a host can veto settlement on the synchronous path — the webhook
    # path deliberately has no veto, since money that already moved cannot be
    # rejected.
    class Complete < Spree::Workflow
      hooks :validate, :after_complete

      # @param payment_session [Spree::PaymentSession]
      # @param params [Hash] gateway-specific completion params from the client
      def perform(payment_session:, params: {})
        super

        # A replayed confirm on a settled session is idempotent, not an error.
        halt!(payment_session) if payment_session.completed?

        run_hooks :validate

        external_step :complete_at_gateway

        run_hooks :after_complete
        success(payment_session.reload)
      end

      private

      def complete_at_gateway
        payment_session.payment_method.complete_payment_session(
          payment_session: payment_session,
          params: params
        )
      rescue Spree::Core::GatewayError => error
        failure(payment_session, error.message)
      end
    end
  end
end
