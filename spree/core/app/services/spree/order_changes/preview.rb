module Spree
  module OrderChanges
    # What an order would look like with a set of actions applied: the totals
    # after it, and how far the balance moves.
    #
    # The actions are added and applied for real — refused by the same rules
    # and `validate` hook Save meets — to a fresh copy of the order, inside a
    # transaction that is always rolled back. The figures are the server's
    # own answer, never an approximation, and nothing the preview touched is
    # kept. The set is opened without Begin or Request, so their lifecycle
    # hooks never fire for a preview; item edits do run Spree::Orders::UpsertItems,
    # whose hooks see every preview the way they see every save.
    class Preview
      prepend Spree::ServiceModule::Base

      # @param order [Spree::Order]
      # @param actions [Array<Hash>] as Spree::OrderChanges::Apply takes them
      # @param requested_by [Object, nil]
      # @return [Spree::ServiceModule::Result] value is a Spree::OrderChangePreview
      def call(order:, actions:, requested_by: nil)
        outcome = nil

        ApplicationRecord.transaction(requires_new: true) do
          # Locked first, as Begin and Confirm do: a preview that held the
          # open-set slot before the order row would deadlock a save.
          outcome = preview(Spree::Order.lock.find(order.id), actions, requested_by)
          raise ActiveRecord::Rollback
        end

        outcome
      rescue ActiveRecord::RecordNotUnique
        # A set opened and left requested while this preview ran.
        failure(order, :order_change_in_progress)
      end

      private

      def preview(scratch_order, actions, requested_by)
        refusal = Spree::OrderChanges::Begin.refusal_for(scratch_order)
        return failure(scratch_order, refusal) if refusal

        previous_total = scratch_order.total
        order_change = scratch_order.order_changes.create!(requested_by: requested_by)

        Array(actions).each do |attributes|
          added = Spree.order_change_add_action_workflow.call(order_change: order_change, **attributes.to_h.symbolize_keys)
          return added if added.failure?
        end

        applied = Spree::OrderChanges::ApplyActions.call(order_change: order_change)
        return applied if applied.failure?

        success(Spree::OrderChangePreview.from_order(scratch_order, previous_total: previous_total))
      end
    end
  end
end
