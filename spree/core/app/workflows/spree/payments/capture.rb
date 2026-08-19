module Spree
  module Payments
    # Captures an authorized payment at the gateway.
    #
    # Owns the flow end to end: the atomic claim, the gateway round trip
    # (an external_step, so it can never share a workflow-opened
    # transaction), the locked bookkeeping with its settled-concurrently
    # recheck, the partial-capture split, and the remainder's
    # re-authorization. Spree::Payment keeps only gateway mechanics —
    # gateway_options, handle_response, error translation.
    class Capture < Spree::Workflow
      include Spree::InstrumentsGatewayCalls

      hooks :validate, :before_capture, :after_capture

      # @param payment [Spree::Payment] a completed payment is a no-op
      # @param amount [Integer, nil] amount in cents; nil captures in full,
      #   a smaller amount splits the remainder into a new pending payment
      def perform(payment:, amount: nil)
        super
        @amount = amount || payment.money.amount_in_cents

        step :ensure_capturable
        # Veto point — fraud holds, manual review. Before any money moves.
        run_hooks :validate
        run_hooks :before_capture

        # Claiming before the gateway call is what makes a stale instance
        # harmless: a payment another writer already settled refuses the
        # claim, and the capture reports success without touching the
        # gateway or recording a second capture event.
        step :claim

        external_step :capture_at_gateway
        step :record_capture
        external_step :authorize_remainder

        run_hooks :after_capture
        payment.publish_event('payment.captured')
        success(payment.reload)
      end

      private

      attr_reader :response, :remainder

      # An already-captured payment returns success rather than failing:
      # capture is naturally idempotent and double-submitted admin actions
      # must not surface as errors. A failed payment is capturable — the
      # failure may have been a gateway outage, and retrying is running
      # this workflow again.
      def ensure_capturable
        halt!(payment) if payment.completed?
        return if payment.pending? || payment.checkout? || payment.processing? || payment.failed?

        failure(payment, :payment_not_capturable)
      end

      def claim
        halt!(payment) unless payment.started_processing!
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end

      def capture_at_gateway
        @response = payment.protect_from_connection_error do
          instrument_gateway_call(:capture, payment.payment_method) do
            payment.payment_method.capture(@amount, payment.response_code, payment.gateway_options)
          end
        end

        # A failed response writes no money records, so it needs no lock —
        # handle_response records the failure and raises.
        payment.handle_response(@response, :complete) unless @response.success?
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end

      # Locked because the webhook settling the same payment races this
      # request. The DB recheck — deliberately not a reload, which would
      # discard the in-memory source (card numbers never persist) — makes
      # the capture event exactly-once.
      def record_capture
        already_captured = false
        payment.owner.with_lock do
          if Spree::Payment.where(id: payment.id, status: 'completed').exists?
            already_captured = true
          else
            payment.capture_events.create!(amount: ::Money.new(@amount, payment.currency).to_f)
            # Split before completing, so payment.completed publishes with
            # the captured amount and the order recomputes from correct rows.
            @remainder = payment.split_uncaptured_amount
            payment.handle_response(@response, :complete)
          end
        end
        halt!(payment) if already_captured
      end

      # The remainder's authorization is its own network call, so it stays
      # outside the lock.
      def authorize_remainder
        return if remainder.blank?

        result = Spree.payment_process_workflow.call(payment: remainder, action: :authorize)
        failure(remainder, result.error.value.to_s) if result.failure?
      end
    end
  end
end
