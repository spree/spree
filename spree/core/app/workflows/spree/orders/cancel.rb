module Spree
  module Orders
    # Cancels an order — the orchestration that used to hide inside
    # Order#after_cancel, as declared steps: the cancellation record, the
    # status flip and fulfillment cancellation commit atomically (with the
    # after_cancel hook inside the transaction), then payment settlement
    # runs as external I/O — voids and refunds are gateway calls and must
    # never share a database transaction — followed by money and status
    # recomputation and the order.canceled event after commit.
    #
    # Legacy `canceler:` and `canceled_at:` remain valid; new keywords are
    # additive and stored on the Spree::OrderCancellation record.
    class Cancel < Spree::Workflow
      DEFAULT_REASON = 'other'.freeze

      argument :order, Spree::Order
      argument :canceler, default: nil
      argument :canceled_at, default: nil
      argument :reason, String, default: DEFAULT_REASON
      argument :note, default: nil
      argument :restock_items, :boolean, default: false
      argument :refund_payments, :boolean, default: false
      argument :refund_amount, default: nil
      argument :notify_customer, :boolean, default: false
      returns -> { order.reload }

      rescue_from ActiveRecord::RecordInvalid, StateMachines::InvalidTransition do |_error|
        failure(order)
      end

      step :ensure_cancellable
      step :normalize, provides: [:decided_at, :amount_to_refund]
      transaction do
        step :record_cancellation, provides: [:cancellation]
        step :mark_canceled
        step :cancel_fulfillments
        run_hooks :after_cancel
      end
      external_step :settle_payments
      step :recalculate_totals, with: -> { Spree::Orders::RecalculateTotals }
      step :recompute_statuses, with: -> { Spree::Orders::RecomputeStatuses }
      step :send_legacy_webhook
      emit 'order.canceled', payload: -> { order.event_payload.merge(notify_customer: notify_customer) }

      private

      def ensure_cancellable
        failure(order) unless order.allow_cancel?
      end

      def normalize
        amount = refund_amount
        amount ||= order.payment_total if refund_payments
        { decided_at: canceled_at || Time.current, amount_to_refund: amount }
      end

      def record_cancellation
        {
          cancellation: order.cancellations.create!(
            reason: reason,
            note: note,
            restock_items: restock_items,
            refund_payments: refund_payments,
            refund_amount: amount_to_refund,
            notify_customer: notify_customer,
            canceled_by: canceler,
            created_at: decided_at
          )
        }
      end

      def mark_canceled
        changes = { status: 'canceled', canceled_at: decided_at }
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

      def send_legacy_webhook
        order.send_order_canceled_webhook
      end
    end
  end
end
