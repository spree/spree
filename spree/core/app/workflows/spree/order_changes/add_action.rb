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
      # @param discount [Spree::Discount, nil] the manual row to update or remove
      # @param label [String, nil] a discount's name
      # @param value [Numeric, String, nil] what a new discount takes off: money for `flat`, a rate for `percent`
      # @param value_type [String, nil] 'flat' or 'percent'
      # @param amount [Numeric, String, nil] a discount row's new amount, zero or less
      # @param metadata [Hash]
      def perform(order_change:, kind:, line_item: nil, variant: nil, quantity: nil, fulfillment: nil,
                  delivery_method: nil, discount: nil, label: nil, value: nil, value_type: nil, amount: nil,
                  metadata: {})
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
          # A discount on a line is about the line, not its product.
          variant: variant || (line_item&.variant unless Spree::OrderChangeAction::DISCOUNT_KINDS.include?(kind.to_s)),
          quantity: quantity,
          fulfillment: fulfillment,
          delivery_method: delivery_method,
          discount: discount,
          label: label,
          value: value,
          value_type: value_type || ('flat' if kind.to_s == 'add_discount'),
          amount: amount,
          # Loaded once and then kept, so adding many actions counts none of them twice.
          position: order_change.actions.load.size,
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
