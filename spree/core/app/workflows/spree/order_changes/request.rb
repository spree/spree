module Spree
  module OrderChanges
    # Submits a pending change set for confirmation and freezes its actions.
    class Request < Spree::Workflow
      hooks :after_request

      # @param order_change [Spree::OrderChange] must be pending, with actions
      def perform(order_change:)
        super

        failure(order_change, :order_change_not_pending) unless order_change.pending?
        failure(order_change, :order_change_empty) if order_change.actions.empty?

        ApplicationRecord.transaction do
          order_change.update!(status: 'requested', requested_at: Time.current)
          run_hooks :after_request
        end

        # Sent after the outermost commit — Spree::OrderChanges::Apply runs
        # this inside a transaction a failed confirm still rolls back — but
        # describing the set as it is now, before that confirm moves it on.
        payload = order_change.event_payload_for('order_change.requested') if Spree::Events.enabled?
        ActiveRecord.after_all_transactions_commit { order_change.publish_event('order_change.requested', payload) }
        success(order_change)
      end
    end
  end
end
