module Spree
  module Payments
    # Captures an authorized payment at the gateway.
    #
    # In the workflow tier because the capture is network I/O: `external_step`
    # refuses to run inside a transaction the workflow opened, so a caller
    # can no longer accidentally hold a database connection open across a
    # gateway round trip. Money movement stays in the model (the state
    # machine and capture events are unchanged) — this owns the boundary,
    # the guards and the extension points around it.
    class Capture < Spree::Workflow
      hooks :validate, :before_capture, :after_capture

      # @param payment [Spree::Payment] a completed payment is a no-op
      # @param amount [Integer, nil] amount in cents; nil captures in full,
      #   a smaller amount splits the remainder into a new pending payment
      def perform(payment:, amount: nil)
        super

        step :ensure_capturable
        # Veto point — fraud holds, manual review. Before any money moves.
        run_hooks :validate
        run_hooks :before_capture

        external_step :capture_at_gateway

        run_hooks :after_capture
        payment.publish_event('payment.captured')
        success(payment.reload)
      end

      private

      # An already-captured payment returns success rather than failing:
      # capture is naturally idempotent and double-submitted admin actions
      # must not surface as errors.
      def ensure_capturable
        halt!(payment) if payment.completed?
        failure(payment, :payment_not_capturable) unless payment.pending? || payment.checkout? || payment.processing?
      end

      def capture_at_gateway
        payment.capture!(amount)
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end
    end
  end
end
