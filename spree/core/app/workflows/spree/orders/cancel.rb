module Spree
  module Orders
    # Cancels an order — the orchestration that used to hide inside
    # Order#after_cancel: the status flip (stamping the reason and note on
    # the order) and fulfillment cancellation commit atomically (with the
    # after_cancel hook inside the transaction), then payment settlement
    # runs as external I/O — voids and refunds are gateway calls and must
    # never share a database transaction — followed by money and status
    # recomputation and the order.canceled event.
    class Cancel < Spree::Workflow
      hooks :before_cancel, :after_cancel

      # @param order [Spree::Order]
      # @param canceler [Object, nil] the user/admin who initiated the cancellation
      # @param canceled_at [Time, nil] timestamp (defaults to Time.current)
      # @param reason [Spree::OrderCancellationReason, nil] the merchant's own
      #   vocabulary; must belong to the order's store
      # @param note [String, nil] staff-facing note
      # @param refund_payments [Boolean] whether captured money is handed back.
      #   False by default: an authorization is always released, but returning
      #   money already taken is its own decision — the shape Shopify, Vendure,
      #   Saleor and WooCommerce all settled on.
      # @param refund_amount [BigDecimal, Numeric, nil] defaults to
      #   order.payment_total when refund_payments is true
      # @param notify_customer [Boolean] hint for subscribers
      # @param restock_items [Boolean, nil] deprecated and ignored — items
      #   always return to stock when their fulfillment is canceled
      def perform(order:, canceler: nil, canceled_at: nil,
                  reason: nil, note: nil,
                  refund_payments: false, refund_amount: nil,
                  notify_customer: false, restock_items: nil)
        super

        unless restock_items.nil?
          Spree::Deprecation.warn('Spree::Orders::Cancel no longer accepts restock_items — it never changed behavior and will be removed in Spree 6.1.')
        end

        step :ensure_cancellable
        step :ensure_reason_belongs_to_store
        step :ensure_refund_amount_is_settleable

        # Veto point — seller policy, already-dispatched guards. Before the
        # transaction: nothing is written yet, and payment settlement has
        # not run.
        run_hooks :before_cancel

        @decided_at = canceled_at || Time.current
        # Coerced because the amount arrives from JSON as a string, and it is
        # compared against money further down — `[amount, remaining].min`
        # raises on a String.
        @amount_to_refund = refund_amount&.to_d
        @amount_to_refund ||= amount_paid if refund_payments

        ApplicationRecord.transaction do
          step :mark_canceled
          step :cancel_fulfillments
          run_hooks :after_cancel
        end

        external_step :notify_fulfillment_providers
        external_step :settle_payments
        external_step :void_tax
        step :recompute_totals, with: -> { Spree.order_recalculate_totals_workflow }
        step :update_statuses, with: -> { Spree.order_update_statuses_service }
        order.publish_event('order.canceled', order.event_payload.merge(notify_customer: notify_customer))
        success(order.reload)
      rescue ActiveRecord::RecordInvalid
        failure(order)
      end

      private

      def ensure_cancellable
        failure(order) unless order.allow_cancel?
      end

      # An ordinary order settles at the gateway, which returns the whole
      # captured payment — there is nowhere to apply a cap. Honouring the
      # request halfway would refund everything while the caller believed
      # they had held part back, so it is refused instead. A shared payment
      # is the case the amount exists for: there it names this order's share.
      def ensure_refund_amount_is_settleable
        return if refund_amount.blank? || order.grouped?

        order.errors.add(:base, Spree.t('errors.messages.refund_amount_requires_shared_payment'))
        failure(order)
      end

      # A reason from another store would label this order with a vocabulary
      # its merchant never wrote — the same scoping rule the controllers apply
      # to every incidental id, enforced here so console and extension callers
      # get it too.
      def ensure_reason_belongs_to_store
        return if reason.nil? || reason.store_id == order.store_id

        order.errors.add(:cancel_reason, :invalid)
        failure(order)
      end

      def mark_canceled
        changes = { status: 'canceled', canceled_at: @decided_at, cancel_reason_id: reason&.id, cancel_note: note }
        changes[:canceler_id] = canceler.id if canceler.present?
        order.update_columns(changes)
      end

      # Restocks each fulfillment's units and cancels it. allow_cancel? already
      # excluded orders with shipped fulfillments.
      #
      # Deliberately not delegated to Spree::Fulfillments::Cancel: that workflow
      # ends with an external_step telling the carrier, which refuses to run
      # inside a transaction — and this runs inside the order's. The carriers
      # are notified in #notify_fulfillment_providers once the transaction has
      # committed, which is the same ordering the fulfillment workflow uses.
      def cancel_fulfillments
        order.fulfillments.each do |fulfillment|
          result = Spree.fulfillment_cancel_workflow.call(
            fulfillment: fulfillment,
            # Carrier I/O cannot run inside this transaction; the providers are
            # told in #notify_fulfillment_providers once it has committed.
            notify_provider: false
          )

          failure(order, result.error) unless result.success?
        end
      end

      # The provider half of cancelling each fulfillment — network I/O, so it
      # runs after the transaction commits. A carrier that rejects the
      # cancellation does not undo the order cancellation; the goods are not
      # going out either way, and the failure surfaces through the provider.
      def notify_fulfillment_providers
        order.fulfillments.each do |fulfillment|
          Spree.fulfillment_stand_down_service.call(fulfillment: fulfillment)
        end
      end

      # Gateway I/O. Payments fully covered by a gift card are only voided,
      # never refunded; everything else releases what was never drawn and,
      # when the caller asked for it, gives back what was.
      def settle_payments
        return settle_grouped_payments if order.grouped?

        if order.gift_card.present? && order.covered_by_store_credit?
          order.payments.completed.store_credits.each(&:void!)
        else
          settle_completed_payments
          order.payments.incomplete.not_store_credits.each do |payment|
            # Failed and invalid payments hold nothing to release.
            next unless payment.can_void?

            result = Spree.payment_void_workflow.call(payment: payment)
            raise Spree::Core::GatewayError, result.error.value.to_s if result.failure?
          end
          order.payments.store_credits.pending.each(&:void!)
        end
      end

      # Every completed payment goes through the gateway's own settle verb, so
      # a hold is always released. What happens to money already drawn is the
      # caller's decision, carried to the adapter: one that can void the charge
      # does so regardless, and one that cannot — Stripe, on a captured
      # PaymentIntent — refunds only when `refund_payments` allows it.
      def settle_completed_payments
        order.payments.completed.each { |payment| payment.cancel!(refund: refund_payments) }
      end

      # What this order has actually been paid. An order placed in a split
      # checkout holds no payments of its own — the customer paid once, against
      # the group — so its position is the sum of its shares.
      #
      # @return [BigDecimal]
      def amount_paid
        return order.payment_total unless order.grouped?

        order.payment_splits.sum(&:net_captured_amount)
      end

      # Canceling one order of a split checkout gives back that order's money
      # and nothing else: the payment is shared, so voiding it would release
      # the siblings' authorization too and un-pay sellers who are still
      # shipping. What comes back is this order's own share — refunded where it
      # has been captured, and simply written down where it has not, since
      # there is nothing to give back until it is drawn.
      #
      # Deliberately not "void the payment when every sibling is canceled too":
      # that reads the siblings' state to decide what to do with shared money,
      # and being wrong about it releases an authorization a seller is still
      # relying on. Writing the share down leaves the payment voidable by
      # whoever cancels last, which reaches the same end without the risk.
      #
      # Store credit and gift cards are refunded like any other share rather
      # than voided: a void releases a whole payment, which on a shared one is
      # the siblings' money too. The credit comes back to the customer either
      # way, and the refund path is the one that can return a part.
      def settle_grouped_payments
        remaining = @amount_to_refund

        order.payment_splits.includes(:payment).each do |split|
          # A parcel dispatching marks its share taken *before* asking the
          # gateway, so a share can read captured while the charge is still in
          # flight. Settling against that would release an authorization the
          # gateway is about to draw on, or hand back money it never took —
          # so a payment mid-capture is left for the operator rather than
          # guessed at.
          next if capture_in_flight?(split)

          # Release what this order had reserved but never drew — the
          # authorization is no longer for anything. Under the row's lock, so
          # a dispatch claiming the same share concurrently either draws before
          # the release or finds nothing left.
          split.with_lock { split.update!(authorized_amount: split.captured_amount) }

          # Give money back only when the caller asked for it, and only up to
          # what they asked for, exactly as the ungrouped path does.
          next unless refund_payments

          refundable = [split.net_captured_amount, remaining].compact.min
          next if refundable <= 0

          result = Spree.refund_create_workflow.call(
            payment: split.payment, amount: refundable, order: order, refunder: canceler
          )
          raise Spree::Core::GatewayError, result.error.value.to_s if result.failure?

          remaining -= refundable if remaining
        end
      end

      # Whether a charge against this share is still in flight.
      #
      # The share itself knows: a parcel reserves what it is about to draw
      # before asking the gateway, and that reservation only becomes captured
      # money once the charge lands. Settling through it would either release
      # an authorization about to be drawn or refund money nobody took, so it
      # is reported for the operator rather than guessed at.
      #
      # @return [Boolean]
      def capture_in_flight?(split)
        return false unless split.capture_in_flight?

        Rails.error.report(
          Spree::Core::GatewayError.new('Payment share is mid-capture; cancellation left it for manual settlement'),
          handled: true,
          context: { order_id: order.id, payment_split_id: split.id },
          source: 'spree.core'
        )
        true
      end

      # Reverses the filed tax document. The canceled sale must stop appearing
      # in the merchant's tax liability.
      def void_tax
        order.tax_provider.void(order)
      end
    end
  end
end
