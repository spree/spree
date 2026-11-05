module Spree
  module OrderChanges
    # Applies a requested change set to its order in one transaction.
    #
    # No money moves here. The order is re-summed and its payment status
    # re-derived — `partially_paid` when the customer owes more, `overcharged`
    # when they are owed some back — and the merchant settles it from the
    # order's payments, as after any edit. `before_confirm` and
    # `after_confirm` handlers read `balance_delta`, but both may run inside a
    # caller's transaction: settling at a gateway belongs in a subscriber to
    # `order_change.confirmed`, which is published after commit.
    #
    # Confirm moves no money at a gateway, so it runs inside a caller's
    # transaction: the return, exchange and claim workflows do, so their status
    # change and the stock it moves commit together. Item edits still ask an
    # external inventory, pricing or tax provider, as any order edit does.
    class Confirm < Spree::Workflow
      hooks :before_confirm, :after_confirm

      # balance_delta: how far the order total moved, positive when the
      # customer owes more. fulfillments: replacements the set created.
      attr_reader :balance_delta, :fulfillments

      # @param order_change [Spree::OrderChange] must be requested
      def perform(order_change:)
        super

        payload = nil
        # requires_new: a failure partway through applying rolls back to here
        # even inside a caller's transaction, instead of leaving half an edit
        # for the caller to commit.
        ApplicationRecord.transaction(requires_new: true) do
          # A second confirm of the same set waited here while the first
          # applied it, and must now see it confirmed.
          order_change.lock_for_transition!
          step :ensure_confirmable
          previous_total = order.total
          step :apply_actions
          order.update_statuses!
          @balance_delta = order.total - previous_total
          order_change.update!(status: 'confirmed', confirmed_at: Time.current)
          run_hooks :before_confirm
          # Built here, so a payload that fails to build rolls the edit back.
          payload = order_change.event_payload_for('order_change.confirmed') if Spree::Events.enabled?
        end

        # Registered before after_confirm: a handler rejecting here cannot
        # undo a confirm that already committed, so its event still goes out.
        ActiveRecord.after_all_transactions_commit { order_change.publish_event('order_change.confirmed', payload) }
        run_hooks :after_confirm
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

      def apply_actions
        result = Spree::OrderChanges::ApplyActions.call(order_change: order_change)
        @fulfillments = result.value if result.success?
        result
      end
    end
  end
end
