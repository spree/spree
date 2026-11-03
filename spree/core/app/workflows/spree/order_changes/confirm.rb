module Spree
  module OrderChanges
    # Applies a requested change set to its order in one transaction.
    #
    # No money moves here. The order is re-summed and its payment status
    # re-derived — `balance_due` when the customer owes more, `credit_owed`
    # when they are owed some back — and the merchant settles it from the
    # order's payments, as after any edit. An extension that wants to settle
    # automatically reads `balance_delta` in an `after_confirm` handler.
    #
    # With no gateway I/O of its own, Confirm is safe to run inside a
    # caller's transaction: the return, exchange and claim workflows do, so
    # their status change and the stock it moves commit together.
    class Confirm < Spree::Workflow
      hooks :before_confirm, :after_confirm

      # balance_delta: how far the order total moved, positive when the
      # customer owes more. fulfillments: replacements the set created.
      attr_reader :balance_delta, :fulfillments

      # @param order_change [Spree::OrderChange] must be requested
      def perform(order_change:)
        super

        step :ensure_confirmable

        ApplicationRecord.transaction do
          order.lock!
          previous_total = order.total
          step :apply_actions
          order.recalculate_totals! if moves_money?
          order.update_statuses!
          @balance_delta = order.total - previous_total
          order_change.update!(status: 'confirmed', confirmed_at: Time.current)
          run_hooks :before_confirm
        end

        run_hooks :after_confirm
        ActiveRecord.after_all_transactions_commit { order_change.publish_event('order_change.confirmed') }
        success(order_change)
      end

      private

      def order
        order_change.order
      end

      def ensure_confirmable
        failure(order_change, :order_change_not_requested) unless order_change.requested?
        failure(order_change, :order_change_order_canceled) if order.canceled?
      end

      # A receipt or a replacement shipment changes no amount on the order,
      # and re-summing a placed order can call out to a tax provider.
      def moves_money?
        order_change.actions.any? { |action| Spree::OrderChangeAction::STOCK_KINDS.exclude?(action.kind) }
      end

      def apply_actions
        result = Spree::OrderChanges::ApplyActions.call(order_change: order_change)
        @fulfillments = result.value if result.success?
        result
      end
    end
  end
end
