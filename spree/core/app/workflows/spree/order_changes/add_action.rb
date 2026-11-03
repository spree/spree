module Spree
  module OrderChanges
    # Appends one proposed mutation to a pending change set. Nothing touches
    # the order until the set is confirmed.
    #
    # The `validate` hook is where an extension refuses an edit — a window
    # after which orders are locked, a product that may not be added after
    # placement — with `workflow.errors.add(...)` and `workflow.reject!`.
    class AddAction < Spree::Workflow
      hooks :validate

      attr_reader :action

      # @param order_change [Spree::OrderChange] must be pending
      # @param kind [String] one of Spree::OrderChangeAction.kinds
      # @param line_item [Spree::LineItem, nil]
      # @param variant [Spree::Variant, nil]
      # @param quantity [Integer, nil]
      # @param fulfillment [Spree::Fulfillment, nil]
      # @param delivery_method [Spree::DeliveryMethod, nil]
      # @param metadata [Hash]
      def perform(order_change:, kind:, line_item: nil, variant: nil, quantity: nil, fulfillment: nil,
                  delivery_method: nil, metadata: {})
        super

        failure(order_change, :order_change_not_pending) unless order_change.pending?
        step :build_action
        run_hooks :validate
        step :save_action

        success(action)
      end

      private

      def build_action
        @action = order_change.actions.build(
          kind: kind.to_s,
          line_item: line_item,
          variant: variant || line_item&.variant,
          quantity: quantity,
          fulfillment: fulfillment,
          delivery_method: delivery_method,
          position: order_change.actions.size,
          metadata: metadata.to_h
        )
      end

      def save_action
        return if action.save

        # Off the collection, so a rejected action is not saved with the set.
        order_change.actions.delete(action)
        failure(action)
      end
    end
  end
end
