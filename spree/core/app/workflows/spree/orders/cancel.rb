module Spree
  module Orders
    # Cancels an order — the orchestration that used to hide inside
    # Order#after_cancel: the cancellation record, the status flip and
    # fulfillment cancellation commit atomically (with the after_cancel
    # hook inside the transaction), then payment settlement runs as
    # external I/O — voids and refunds are gateway calls and must never
    # share a database transaction — followed by money and status
    # recomputation and the order.canceled event.
    class Cancel < Spree::Workflow
      DEFAULT_REASON = 'other'.freeze

      hooks :before_cancel, :after_cancel

      # Hook handlers read this plus the argument readers. Nil when
      # before_cancel runs — the record does not exist yet.
      attr_reader :cancellation

      # @param order [Spree::Order]
      # @param canceler [Object, nil] the user/admin who initiated the cancellation
      # @param canceled_at [Time, nil] timestamp (defaults to Time.current)
      # @param reason [String] one of Spree::OrderCancellation::REASONS
      # @param note [String, nil] staff-facing note
      # @param restock_items [Boolean] whether to return inventory
      # @param refund_payments [Boolean] whether to refund captured payments
      # @param refund_amount [BigDecimal, Numeric, nil] defaults to
      #   order.payment_total when refund_payments is true
      # @param notify_customer [Boolean] hint for subscribers
      def perform(order:, canceler: nil, canceled_at: nil,
                  reason: DEFAULT_REASON, note: nil,
                  restock_items: false, refund_payments: false, refund_amount: nil,
                  notify_customer: false)
        super

        step :ensure_cancellable

        # Veto point — seller policy, already-dispatched guards. Before the
        # transaction: nothing is written yet, and payment settlement has
        # not run.
        run_hooks :before_cancel

        @decided_at = canceled_at || Time.current
        @amount_to_refund = refund_amount
        @amount_to_refund ||= amount_paid if refund_payments

        ApplicationRecord.transaction do
          step :record_cancellation
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

      def record_cancellation
        @cancellation = order.cancellations.create!(
          reason: reason,
          note: note,
          restock_items: restock_items,
          refund_payments: refund_payments,
          refund_amount: @amount_to_refund,
          notify_customer: notify_customer,
          canceled_by: canceler,
          created_at: @decided_at
        )
      end

      def mark_canceled
        changes = { status: 'canceled', canceled_at: @decided_at }
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
          fulfillment.provider.cancel_fulfillment(fulfillment)
        end
      end

      # Gateway I/O. Payments fully covered by a gift card are only voided,
      # never refunded; everything else cancels captured payments (void or
      # refund at the gateway's discretion) and voids what never completed.
      def settle_payments
        return settle_grouped_payments if order.grouped?

        if order.gift_card.present? && order.covered_by_store_credit?
          order.payments.completed.store_credits.each(&:void!)
        else
          order.payments.completed.each(&:cancel!)
          order.payments.incomplete.not_store_credits.each do |payment|
            # Failed and invalid payments hold nothing to release.
            next unless payment.can_void?

            result = Spree.payment_void_workflow.call(payment: payment)
            raise Spree::Core::GatewayError, result.error.value.to_s if result.failure?
          end
          order.payments.store_credits.pending.each(&:void!)
        end
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
