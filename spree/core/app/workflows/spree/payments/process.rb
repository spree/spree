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
        step :limit_to_amount_owed
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

        failure(payment, I18n.t('spree.payment_processing_failed')) if payment.source.blank?

        unless payment.payment_method.supports?(payment.source) || payment.token_based?
          payment.invalidate!
          failure(payment, I18n.t('spree.payment_method_not_supported'))
        end
      end

      # Several live payments can sit on one order, so one is charged only
      # what the others leave owing and shrunk to that before the gateway
      # sees it. A payment the others already cover is refused.
      def limit_to_amount_owed
        # A completed payment is never charged again (claim halts on it), so
        # its recorded amount is left alone.
        return if payment.completed?

        owed = payment.amount_owed_by_order(including_in_flight: true)
        return if owed.nil? || payment.amount <= owed

        failure(payment, I18n.t('spree.order_payment_already_covered')) unless owed.positive?

        # Guarded against a settlement landing since the check above: a
        # payment that completed meanwhile keeps its amount, and like claim
        # below, that is a success rather than an error.
        halt!(payment) unless payment.resize_unless_completed!(owed)
      end

      # A payment that completed concurrently — the webhook settled it while
      # this request was in flight — is a success, not an error.
      # The limit again, under the order's row lock and together with the
      # claim: of two payments processed at once on one order, the second
      # reads after the first has claimed (processing), so it is limited to
      # what the first leaves owing rather than both taking the full balance.
      def claim
        outcome = with_order_lock do
          owed = payment.amount_owed_by_order(including_in_flight: true)
          if owed && payment.amount > owed
            next :covered unless owed.positive?
            next :settled unless payment.resize_unless_completed!(owed)
          end
          payment.started_processing! ? :claimed : :settled
        end
        failure(payment, I18n.t('spree.order_payment_already_covered')) if outcome == :covered
        halt!(payment) if outcome == :settled
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end

      def with_order_lock(&)
        payment.order_id ? payment.owner.with_lock(&) : yield
      end

      def process_at_gateway
        verb = action || (payment.payment_method&.capture_at_checkout? ? :purchase : :authorize)

        response = payment.protect_from_connection_error do
          instrument_gateway_call(verb, payment.payment_method) do
            payment.payment_method.public_send(
              verb, payment.payment_method.gateway_amount(payment.amount, payment.currency), payment.source, payment.gateway_options
            )
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
