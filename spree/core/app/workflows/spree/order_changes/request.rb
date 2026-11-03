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

        # After the outermost commit: Spree::OrderChanges::Apply runs this
        # inside a transaction that a failed confirm still rolls back.
        ActiveRecord.after_all_transactions_commit { order_change.publish_event('order_change.requested') }
        success(order_change)
      end
    end
  end
end
