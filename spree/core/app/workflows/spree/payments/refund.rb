module Spree
  module Payments
    # Refunds a captured payment at the gateway.
    #
    # In the workflow tier because the refund is network I/O. Today
    # `Spree::Refund` fires its gateway call from an `after_create` callback,
    # so the request runs inside whatever transaction the caller happens to
    # hold. Creating the refund through this workflow puts the call in an
    # `external_step` instead, which refuses to run inside a workflow-opened
    # transaction — the record is committed first, then the gateway is
    # called, then the totals are refreshed.
    class Refund < Spree::Workflow
      hooks :validate, :before_refund, :after_refund

      # The created refund — hook handlers read it (nil during :validate).
      attr_reader :refund

      # @param payment [Spree::Payment] the captured payment to reverse
      # @param amount [BigDecimal, Numeric, nil] defaults to the full
      #   creditable balance
      # @param reason [Spree::RefundReason, nil] defaults to the store's
      #   return-processing reason
      # @param refunder [Object, nil] the admin issuing the refund
      def perform(payment:, amount: nil, reason: nil, refunder: nil)
        super

        step :ensure_refundable
        @amount_to_refund = amount || payment.credit_allowed
        step :ensure_amount_within_balance

        # Veto point — before the refund record exists and before any money
        # moves back.
        run_hooks :validate
        run_hooks :before_refund

        # Committed before the gateway call: a refund row with no
        # transaction_id is recoverable, a gateway credit with no record is
        # not.
        external_step :issue_refund

        run_hooks :after_refund
        payment.publish_event('payment.refunded')
        success(refund)
      end

      private

      def ensure_refundable
        failure(payment, :payment_not_refundable) unless payment.completed?
      end

      def ensure_amount_within_balance
        return if @amount_to_refund.to_d.positive? && @amount_to_refund.to_d <= payment.credit_allowed.to_d

        failure(payment, :refund_amount_exceeds_balance)
      end

      # Spree::Refund performs the gateway credit in an after_create
      # callback; creating it here keeps that call outside any transaction
      # this workflow opened.
      def issue_refund
        @refund = payment.refunds.create!(
          amount: @amount_to_refund,
          reason: reason || Spree::RefundReason.return_processing_reason(payment.order&.store),
          refunder: refunder
        )
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end
    end
  end
end
