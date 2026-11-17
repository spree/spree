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

        failure(payment, I18n.t('spree.payment_processing_failed')) if payment.source.blank?

        unless payment.payment_method.supports?(payment.source) || payment.token_based?
          payment.invalidate!
          failure(payment, I18n.t('spree.payment_method_not_supported'))
        end
      end

      # Several live payments can sit on one order, so one is charged only
      # what the others leave owing. Under the order's row lock, the payment's
      # current status, what is owed, the resize to it and the claim are read
      # and written together: of two payments processed at once on one order,
      # the second reads after the first has claimed (processing), so it is
      # limited to what the first leaves owing rather than both taking the
      # full balance.
      def claim
        outcome = with_order_lock { claim_within_amount_owed }
        failure(payment, I18n.t('spree.order_payment_already_covered')) if outcome == :covered
        halt!(payment) if outcome == :settled
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end

      # The row decides, since the instance may be stale: its amount is the one
      # charged, and its status says whose the payment is. A payment another
      # run claimed (processing) or one that settled is that run's — a success
      # here, not an error. A dead one (void, invalid) is left to
      # started_processing!, which raises for it, so it still fails.
      def claim_within_amount_owed
        status = refresh_from_row
        return :settled if %w[processing completed].include?(status)

        if Spree::Payment::RESIZABLE_STATUSES.include?(status)
          owed = payment.amount_owed_by_order(including_in_flight: true)
          if owed && payment.amount > owed
            return :covered unless owed.positive?
            return claim_within_amount_owed unless payment.resize_if_unclaimed!(owed)
          end
        end

        payment.started_processing! ? :claimed : :settled
      end

      # Reads the status and amount another run may have written since this
      # instance was loaded. Deliberately not a reload, which would discard the
      # in-memory source (card numbers never persist).
      def refresh_from_row
        return payment.status unless payment.persisted?

        status, amount = Spree::Payment.unscoped.where(id: payment.id).pick(:status, :amount)
        payment.amount = amount
        payment.clear_attribute_changes(%i[amount])
        status
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
