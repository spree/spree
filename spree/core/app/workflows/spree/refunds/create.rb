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
    #
    # A refund paid as store credit takes the same path without the gateway:
    # the credit already holds the money, so the row is written completed and
    # the payment is never credited. It runs inside the caller's transaction,
    # beside the credit it records.
    class Create < Spree::Workflow
      hooks :validate, :before_refund, :after_refund

      # The created refund — hook handlers read it (nil during :validate).
      attr_reader :refund

      # @param payment [Spree::Payment] the captured payment to reverse
      # @param amount [BigDecimal, Numeric, nil] defaults to the full
      #   creditable balance
      # @param reason [Spree::RefundReason, nil] defaults to the store's
      #   return-processing reason
      # @param refunder [Object, nil] who is issuing it (see Spree.actor_classes)
      # @param originator [Object, nil] what triggered the refund — a
      #   Spree::Return, Exchange or Claim; nil for a manual refund
      # @param order [Spree::Order, nil] which order is being put right.
      #   Required only when the payment is shared by a split checkout, where
      #   it covers several orders and the payment cannot say which one this
      #   refund is for; otherwise the payment's own order is taken.
      # @param tax_amount [BigDecimal, Numeric] the tax inside +amount+, when
      #   what is being refunded carried tax (see Spree::Refund#tax_amount)
      # @param store_credit [Spree::StoreCredit, nil] the credit the money went
      #   back as, instead of to the payment
      def perform(payment:, amount: nil, reason: nil, refunder: nil, originator: nil, order: nil, tax_amount: 0,
                  store_credit: nil)
        super

        step :ensure_refundable
        @amount_to_refund = amount || [payment.credit_allowed.to_d, unrecorded_credit_bound].compact.min
        step :ensure_amount_within_balance

        # Veto point — before the refund record exists and before any money
        # moves back.
        run_hooks :validate
        run_hooks :before_refund

        step :create_refund, on_flow_failure: :destroy_uncredited_refund
        if store_credit
          step :refresh_order_payment_total
        else
          external_step :credit_at_gateway
        end

        run_hooks :after_refund
        # A requested refund is confirmed by the provider's webhook, which
        # publishes payment.refunded then.
        if refund.requested?
          refund.publish_event('refund.requested')
        else
          payment.publish_event('payment.refunded', nil, refund_id: refund.prefixed_id)
        end
        success(refund)
      end

      private

      def ensure_refundable
        failure(payment, :payment_not_refundable) unless payment.completed?
      end

      def ensure_amount_within_balance
        amount = @amount_to_refund.to_d
        unless amount.positive? && amount <= payment.credit_allowed.to_d && amount <= refundable_share
          failure(payment, :refund_amount_exceeds_balance)
        end
        ensure_within_unrecorded_credit_bound
      end

      # Store credit issued before credit was recorded as refunds wrote no
      # refund row, so the payment's own balance does not know it was given
      # back. Until the backfill records it, the order as a whole bounds the
      # refund. Not checked while recording a credit, which its issuer has
      # already bounded.
      def ensure_within_unrecorded_credit_bound
        bound = unrecorded_credit_bound
        failure(payment, :refund_exceeds_order_balance) if bound && @amount_to_refund.to_d > bound
      end

      # @return [BigDecimal, nil] what the order has left to give back, or nil
      #   when it holds no unrecorded credit
      def unrecorded_credit_bound
        return if store_credit || refunded_order.nil?

        unrecorded = refunded_order.unrecorded_store_credit_refund_total
        return unless unrecorded.positive?

        refunded_order.refundable_payment_total - unrecorded
      end

      def refunded_order
        order || payment.order
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
      # The order is locked first, in the order returns, captures and
      # cancellation take it, and the figures are re-read with locking reads:
      # on MySQL a plain read inside a caller's transaction answers from the
      # snapshot taken at its first read, and would miss a refund committed
      # since. The per-order share is re-read the same way. `Spree::Refund`
      # validates against `credit_allowed`, which is the whole payment's
      # balance and says nothing about whose money it is — so on a shared
      # payment the model cannot catch two refunds that each fit the payment
      # but together overdraw one child's share.
      def create_refund
        ApplicationRecord.transaction do
          Spree::Order.lock.find(refunded_order.id) if refunded_order

          payment.with_lock do
            ensure_balance_still_available
            ensure_within_unrecorded_credit_bound

            # Requested until the gateway answers, so a crash before then leaves
            # a visible requested row, not one that reads as completed. Store
            # credit has already been issued, so its row is completed at once;
            # the credit's id stands in for a gateway reference, which also
            # makes Refund#perform! a no-op on it.
            @refund = payment.refunds.create!(
              status: store_credit ? 'completed' : 'requested',
              transaction_id: store_credit&.prefixed_id,
              store_credit: store_credit,
              amount: @amount_to_refund,
              order: refunded_order,
              reason: reason || Spree::RefundReason.return_processing_reason(refund_store),
              refunder: refunder,
              originator: originator,
              tax_amount: tax_amount
            )
          end
        end
      end

      # Re-reads what the payment, and on a shared payment the named order's
      # share, can still give back now that they are locked, so a refund that
      # landed since the pre-flight check is counted.
      def ensure_balance_still_available
        amount = @amount_to_refund.to_d
        refunded = payment.refunds.not_failed.lock.pluck(:amount).sum(0.to_d)
        failure(payment, :refund_amount_exceeds_balance) if amount > payment.amount - payment.offsets_total.abs - refunded
        return unless payment.grouped?

        split = order && Spree::PaymentSplit.lock.find_by(payment_id: payment.id, order_id: order.id)
        share_refunded = Spree::Refund.not_failed.where(payment_id: payment.id, order_id: order&.id).lock.pluck(:amount).sum(0.to_d)
        failure(payment, :refund_amount_exceeds_balance) if split.nil? || amount > split.captured_amount - share_refunded
      end

      # The store the default reason belongs to. A payment shared by a split
      # checkout has no order of its own, so it is asked through whichever
      # order is being refunded — and failing that the current store, since a
      # store-less reason would be created global and reused everywhere.
      def refund_store
        (order || payment.order)&.store || payment.owner&.store || Spree::Current.store
      end

      # Re-sums what the order has been paid, as Refund#perform! does once a
      # gateway refund is credited.
      def refresh_order_payment_total
        refund.order&.refresh_payment_total!
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
