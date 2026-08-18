module Spree
  module Payments
    # Processes a checkout payment at the gateway — authorize or purchase,
    # chosen by the payment method's capture timing unless the caller
    # forces a verb. The storefront batch (Purchase::PaymentProcessing)
    # calls this once per payment; Payments::Capture re-authorizes a
    # partial capture's remainder through it.
    class Process < Spree::Workflow
      include Spree::InstrumentsGatewayCalls

      hooks :validate, :before_process, :after_process

      # @param payment [Spree::Payment]
      # @param action [Symbol, nil] :authorize or :purchase; nil follows the
      #   payment method's capture timing
      def perform(payment:, action: nil)
        super

        step :ensure_processable
        run_hooks :validate
        run_hooks :before_process

        step :claim
        external_step :process_at_gateway

        run_hooks :after_process
        success(payment.reload)
      end

      private

      # The machine-era preconditions, preserved: an in-flight payment is
      # left alone, a source-required method without a source cannot
      # process, and an unsupported card brand invalidates the payment.
      def ensure_processable
        halt!(payment) if payment.processing?
        return unless payment.payment_method&.source_required?

        failure(payment, Spree.t(:payment_processing_failed)) if payment.source.blank?

        unless payment.payment_method.supports?(payment.source) || payment.token_based?
          payment.invalidate!
          failure(payment, Spree.t(:payment_method_not_supported))
        end
      end

      # A payment that completed concurrently — the webhook settled it while
      # this request was in flight — is a success, not an error.
      def claim
        halt!(payment) unless payment.started_processing!
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end

      def process_at_gateway
        verb = action || (payment.payment_method&.capture_at_checkout? ? :purchase : :authorize)

        response = payment.protect_from_connection_error do
          instrument_gateway_call(verb, payment.payment_method) do
            payment.payment_method.public_send(verb, payment.money.amount_in_cents, payment.source, payment.gateway_options)
          end
        end

        payment.handle_response(response, verb == :purchase ? :complete : :pend)
        # Only reached when handle_response accepted the response — a
        # purchase moved the funds, so the capture is recorded.
        payment.capture_events.create!(amount: payment.amount) if verb == :purchase
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end
    end
  end
end
