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
      # @param amount [BigDecimal, nil] in the currency's own units; nil
      #   captures in full, a smaller amount splits the remainder into a new
      #   pending payment. An Integer is read as hundredths of the currency,
      #   the pre-6.0 contract (deprecated, removed in 6.5).
      def perform(payment:, amount: nil)
        super
        @amount = capture_amount(amount)

        step :ensure_capturable
        step :ensure_within_payment_amount
        step :ensure_within_amount_owed
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

      def capture_amount(amount)
        return payment.amount if amount.nil?
        return Spree::Money::Rounding.to_currency(amount, payment.currency) unless amount.is_a?(Integer)

        Spree::Deprecation.warn(
          'Passing an Integer amount to the payment capture workflow is deprecated and is read as hundredths of ' \
          'the currency. Pass the amount in the currency\'s own units as a BigDecimal; removed in Spree 6.3.'
        )
        Spree::Money::Rounding.from_hundredths(amount)
      end

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

      # A capture takes some or all of what was authorized, never more: a
      # gateway may let a larger figure through, and the books would then
      # carry a capture the authorization never covered. Nor nothing, or less
      # than nothing — every caller gets the same rule, not only the API.
      def ensure_within_payment_amount
        failure(payment, :capture_amount_not_positive) unless @amount.positive?
        return if @amount <= payment.amount

        failure(payment, :capture_exceeds_payment_amount)
      end

      # Other payments on the order may have captured some of its total
      # already; this one may take only what they left owing.
      def ensure_within_amount_owed
        owed = payment.amount_owed_by_order(including_in_flight: false)
        return if owed.nil? || @amount <= owed

        failure(payment, I18n.t('spree.capture_exceeds_amount_owed', amount: Spree::Money.new(owed, currency: payment.currency).to_s))
      end

      # The owed check again, under the order's row lock and together with
      # the claim. A payment being charged sits in processing until it is
      # recorded, and here it counts as taken: of two captures racing on one
      # order, the second reads after the first has claimed, so both cannot
      # pass a check made before either moved money.
      def claim
        owed = nil
        claimed = with_order_lock do
          owed = payment.amount_owed_by_order(including_in_flight: false, including_processing: true)
          next :over if owed && @amount > owed

          payment.started_processing!
        end
        if claimed == :over
          failure(payment, I18n.t('spree.capture_exceeds_amount_owed', amount: Spree::Money.new(owed, currency: payment.currency).to_s))
        end
        halt!(payment) unless claimed
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end

      def with_order_lock(&)
        payment.order_id ? payment.owner.with_lock(&) : yield
      end

      def capture_at_gateway
        @response = payment.protect_from_connection_error do
          instrument_gateway_call(:capture, payment.payment_method) do
            payment.payment_method.capture(
              payment.payment_method.gateway_amount(@amount, payment.currency), payment.response_code, payment.gateway_options
            )
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
            payment.capture_events.create!(amount: @amount)
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
        # What the order still owes was captured: holding the rest would only
        # keep the customer's money tied up.
        return remainder.void! if remainder.amount_owed_by_order(including_in_flight: true)&.zero?

        result = Spree.payment_process_workflow.call(payment: remainder, action: :authorize)
        failure(remainder, result.error.value.to_s) if result.failure?
      end
    end
  end
end
