module Spree
  module OrderChanges
    # What an order would look like with a change set applied: the totals
    # after it, and how far the balance moves.
    #
    # The actions are applied for real to a freshly loaded copy of the order
    # and re-summed with the same code Confirm runs, inside a transaction
    # that is always rolled back — so the preview is the server's own answer,
    # never an approximation, and nothing it touched is kept. Pure read: no
    # hooks, no events.
    class Preview
      prepend Spree::ServiceModule::Base

      # @param order_change [Spree::OrderChange] saved or built in memory; its
      #   actions are what gets previewed
      # @return [Spree::ServiceModule::Result] value is a Spree::OrderChangePreview
      def call(order_change:)
        shown_order = order_change.order
        outcome = nil

        ApplicationRecord.transaction(requires_new: true) do
          scratch_order = Spree::Order.find(shown_order.id)
          previous_total = scratch_order.total
          order_change.order = scratch_order

          result = Spree::OrderChanges::ApplyActions.call(order_change: order_change)
          outcome =
            if result.success?
              scratch_order.recalculate_totals!
              success(Spree::OrderChangePreview.from_order(scratch_order.reload, previous_total: previous_total))
            else
              result
            end

          raise ActiveRecord::Rollback
        end

        outcome
      ensure
        # The caller's order instance was never touched; hand it back.
        order_change.order = shown_order if shown_order
      end
    end
  end
end
