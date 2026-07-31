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

      hooks :after_cancel

      # after_cancel handlers read this plus the argument readers.
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

        @decided_at = canceled_at || Time.current
        @amount_to_refund = refund_amount
        @amount_to_refund ||= order.payment_total if refund_payments

        ApplicationRecord.transaction do
          step :record_cancellation
          step :mark_canceled
          step :cancel_fulfillments
          run_hooks :after_cancel
        end

        external_step :settle_payments
        step :recompute_totals, with: -> { Spree.order_recalculate_totals_workflow }
        step :recompute_statuses, with: -> { Spree::Orders::RecomputeStatuses }
        order.send_order_canceled_webhook
        order.publish_event('order.canceled', order.event_payload.merge(notify_customer: notify_customer))
        success(order.reload)
      rescue ActiveRecord::RecordInvalid, StateMachines::InvalidTransition
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

      # Canceling a fulfillment restocks its inventory (Spree::Fulfillment's
      # own cancel semantics); allow_cancel? already excluded orders with
      # shipped fulfillments.
      def cancel_fulfillments
        order.fulfillments.each(&:cancel!)
      end

      # Gateway I/O. Payments fully covered by a gift card are only voided,
      # never refunded; everything else cancels captured payments (void or
      # refund at the gateway's discretion) and voids what never completed.
      def settle_payments
        if order.gift_card.present? && order.covered_by_store_credit?
          order.payments.completed.store_credits.each(&:void!)
        else
          order.payments.completed.each(&:cancel!)
          order.payments.incomplete.not_store_credits.each(&:void_transaction!)
          order.payments.store_credits.pending.each(&:void!)
        end
      end
    end
  end
end
