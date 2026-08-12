module Spree
  module Refunds
    # Creates a refund and credits it back at the gateway.
    #
    # In the workflow tier because the credit is network I/O. The refund row
    # commits first, then the gateway is called from an external_step — a row
    # with no transaction_id is recoverable, a gateway credit with no record
    # is not. On a clean gateway failure the uncredited row is destroyed
    # (credit_allowed sums every refund row, so a dangling one would block the
    # retry); a crash between the two leaves the row for reconciliation.
    class Create < Spree::Workflow
      hooks :validate, :before_refund, :after_refund

      # The created refund — hook handlers read it (nil during :validate).
      attr_reader :refund

      # @param payment [Spree::Payment] the captured payment to reverse
      # @param amount [BigDecimal, Numeric, nil] defaults to the full
      #   creditable balance
      # @param reason [Spree::RefundReason, nil] defaults to the store's
      #   return-processing reason
      # @param refunder [Object, nil] the admin issuing the refund
      # @param originator [Object, nil] what triggered the refund — a
      #   Spree::Return, Exchange or Claim; nil for a manual refund
      def perform(payment:, amount: nil, reason: nil, refunder: nil, originator: nil)
        super

        step :ensure_refundable
        @amount_to_refund = amount || payment.credit_allowed
        step :ensure_amount_within_balance

        # Veto point — before the refund record exists and before any money
        # moves back.
        run_hooks :validate
        run_hooks :before_refund

        step :create_refund, on_flow_failure: :destroy_uncredited_refund
        external_step :credit_at_gateway

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

      def create_refund
        @refund = payment.refunds.create!(
          amount: @amount_to_refund,
          reason: reason || Spree::RefundReason.return_processing_reason(payment.order&.store),
          refunder: refunder,
          originator: originator
        )
      end

      def credit_at_gateway
        refund.perform!
      rescue Spree::Core::GatewayError => error
        failure(refund, error.message)
      end

      # Runs when a step after create_refund fails. Only an uncredited row is
      # destroyed — a present transaction_id means the money moved, and the
      # record must survive whatever failed afterwards.
      def destroy_uncredited_refund
        refund.destroy! if refund&.transaction_id.blank?
      end
    end
  end
end
