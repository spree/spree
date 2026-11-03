module Spree
  module OrderChanges
    # Discards an open change set. Nothing was applied, so nothing is undone;
    # the set is kept as a record of what was proposed.
    class Cancel < Spree::Workflow
      hooks :after_cancel

      # @param order_change [Spree::OrderChange] must be pending or requested
      def perform(order_change:)
        super

        ApplicationRecord.transaction do
          # The same locks Confirm takes, so a cancel racing a confirm sees
          # the set as it was left rather than overwriting a confirmed one.
          order_change.order.lock!
          order_change.lock!
          failure(order_change, :order_change_not_open) unless order_change.open?
          order_change.update!(status: 'canceled', canceled_at: Time.current)
          run_hooks :after_cancel
        end

        ActiveRecord.after_all_transactions_commit { order_change.publish_event('order_change.canceled') }
        success(order_change)
      end
    end
  end
end
