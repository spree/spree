module Spree
  module OrderChanges
    # What an order would look like with a set of actions applied: the totals
    # after it, and how far the balance moves.
    #
    # The change is opened, added to and applied for real — through the same
    # workflows and hooks Save runs, so a preview is refused exactly when the
    # change would be — on a fresh copy of the order, inside a transaction
    # that is always rolled back. The figures are the server's own answer,
    # never an approximation, and nothing the preview touched is kept: no
    # row, no event.
    class Preview
      prepend Spree::ServiceModule::Base

      # @param order [Spree::Order]
      # @param actions [Array<Hash>] as Spree::OrderChanges::Apply takes them
      # @param requested_by [Object, nil]
      # @return [Spree::ServiceModule::Result] value is a Spree::OrderChangePreview
      def call(order:, actions:, requested_by: nil)
        outcome = nil

        ApplicationRecord.transaction(requires_new: true) do
          scratch_order = Spree::Order.find(order.id)
          previous_total = scratch_order.total

          result = Spree.order_change_apply_service.call(
            order: scratch_order, actions: actions, requested_by: requested_by, confirm: false
          )
          outcome = result.success? ? project(result.value, previous_total) : result

          raise ActiveRecord::Rollback
        end

        outcome
      end

      private

      def project(order_change, previous_total)
        applied = Spree::OrderChanges::ApplyActions.call(order_change: order_change)
        return applied if applied.failure?

        success(Spree::OrderChangePreview.from_order(order_change.order, previous_total: previous_total))
      end
    end
  end
end
