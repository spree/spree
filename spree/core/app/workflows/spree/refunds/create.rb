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
      # @param order [Spree::Order, nil] which order is being put right.
      #   Required only when the payment is shared by a split checkout, where
      #   it covers several orders and the payment cannot say which one this
      #   refund is for; otherwise the payment's own order is taken.
      def perform(payment:, amount: nil, reason: nil, refunder: nil, originator: nil, order: nil)
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
        amount = @amount_to_refund.to_d
        return if amount.positive? && amount <= payment.credit_allowed.to_d && amount <= refundable_share

        failure(payment, :refund_amount_exceeds_balance)
      end

      # What the named order may take back from this payment.
      #
      # A payment shared by a split checkout holds several orders' money, and
      # the whole-payment balance says nothing about whose. Without this bound,
      # refunding one seller's order for more than it was paid would quietly
      # spend a sibling's captured share — the money would go back to the
      # customer, and the other seller would find nothing left to draw.
      #
      # @return [BigDecimal] the payment's own balance when it is not shared
      def refundable_share
        return payment.credit_allowed.to_d unless payment.grouped?

        split = order && payment.payment_splits.find_by(order_id: order.id)
        return 0 if split.nil?

        split.refundable_amount
      end

      # The row is what reserves the balance — credit_allowed sums refund rows —
      # so creation serializes on the payment's row lock. Without it the
      # balance validation is check-then-act, and two concurrent refunds would
      # both validate against the pre-refund balance and both credit.
      #
      # The per-order share is re-read inside the lock for the same reason.
      # `Spree::Refund` validates against `credit_allowed`, which is the whole
      # payment's balance and says nothing about whose money it is — so on a
      # shared payment the model cannot catch two refunds that each fit the
      # payment but together overdraw one child's share.
      def create_refund
        payment.with_lock do
          ensure_share_still_available

          @refund = payment.refunds.create!(
            amount: @amount_to_refund,
            order: order || payment.order,
            reason: reason || Spree::RefundReason.return_processing_reason(refund_store),
            refunder: refunder,
            originator: originator
          )
        end
      end

      # Re-reads the named order's remaining share now that the payment's row
      # is locked, so a sibling refund that landed since the pre-flight check
      # is counted.
      def ensure_share_still_available
        return unless payment.grouped?

        payment.payment_splits.reload
        failure(payment, :refund_amount_exceeds_balance) if @amount_to_refund.to_d > refundable_share
      end

      # The store the default reason belongs to. A payment shared by a split
      # checkout has no order of its own, so it is asked through whichever
      # order is being refunded — and failing that the current store, since a
      # store-less reason would be created global and reused everywhere.
      def refund_store
        (order || payment.order)&.store || payment.owner&.store || Spree::Current.store
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
