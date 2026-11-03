module Spree
  module OrderChanges
    # Discards an open change set. Nothing was applied, so nothing is undone;
    # the set is kept as a record of what was proposed.
    class Cancel < Spree::Workflow
      hooks :after_cancel

      # @param order_change [Spree::OrderChange] must be pending or requested
      def perform(order_change:)
        super

        failure(order_change, :order_change_not_open) unless order_change.open?

        ApplicationRecord.transaction do
          order_change.update!(status: 'canceled', canceled_at: Time.current)
          run_hooks :after_cancel
        end

        order_change.publish_event('order_change.canceled')
        success(order_change)
      end
    end
  end
end
