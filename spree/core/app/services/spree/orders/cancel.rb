module Spree
  module Orders
    class Cancel
      prepend Spree::ServiceModule::Base

      DEFAULT_REASON = 'other'.freeze

      # Cancels an order and records a Spree::OrderCancellation history record.
      # Legacy `canceler:` and `canceled_at:` remain valid; new keywords are additive.
      #
      # @param order [Spree::Order]
      # @param canceler [Object, nil] the user/admin who initiated the cancellation
      # @param canceled_at [Time, nil] timestamp (defaults to Time.current)
      # @param reason [String] one of Spree::OrderCancellation::REASONS
      # @param note [String, nil] staff-facing note
      # @param restock_items [Boolean] whether to return inventory
      # @param refund_payments [Boolean] whether to refund captured payments
      # @param refund_amount [BigDecimal, Numeric, nil] amount to refund;
      #   when refund_payments is true and this is nil, defaults to order.payment_total
      # @param notify_customer [Boolean] hint for subscribers
      # @return [Spree::ServiceModule::Result]
      def call(order:, canceler: nil, canceled_at: nil,
               reason: DEFAULT_REASON, note: nil,
               restock_items: false, refund_payments: false, refund_amount: nil,
               notify_customer: false)
        canceled_at ||= Time.current
        refund_amount ||= order.payment_total if refund_payments

        order.transaction do
          order.cancellations.create!(
            reason: reason,
            note: note,
            restock_items: restock_items,
            refund_payments: refund_payments,
            refund_amount: refund_amount,
            notify_customer: notify_customer,
            canceled_by: canceler,
            created_at: canceled_at
          )

          changes = { canceled_at: canceled_at }
          changes[:canceler_id] = canceler.id if canceler.present?
          order.update_columns(changes)
          order.cancel!
        end

        order.publish_event('order.canceled', order.event_payload.merge(notify_customer: notify_customer))
        success(order.reload)
      rescue ActiveRecord::RecordInvalid, StateMachines::InvalidTransition
        failure(order)
      end
    end
  end
end
