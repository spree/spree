module Spree
  module Carts
    # @deprecated Setting a quantity is a one-item upsert. Call
    #   Spree::Carts::UpsertItems so the change passes the same
    #   'carts.upsert_items.validate' hook every other item mutation does.
    #   Removed in Spree 6.1.
    class SetQuantity
      prepend Spree::ServiceModule::Base

      def call(cart: nil, order: nil, line_item: nil, quantity: nil)
        Spree::Deprecation.warn(
          'Spree::Carts::SetQuantity is deprecated and will be removed in Spree 6.1. ' \
          'Use Spree::Carts::UpsertItems (quantity is set, not added) instead.'
        )
        cart ||= order

        workflow = Spree.cart_upsert_items_workflow.new
        result = workflow.call(
          cart: cart,
          items: [{ variant_id: line_item.variant_id, quantity: quantity }]
        )

        return failure(line_item, result.error) if result.failure?

        # The workflow succeeds on the cart side even when a :validate handler
        # skipped this item — that is the batch contract. This service's
        # callers predate it and expect a failure, so translate the warning.
        rejection = workflow.warnings.first
        return failure(line_item, rejection.message) if rejection

        # Zero removed the row, so there is nothing to reload.
        line_item.destroyed? || quantity.to_i <= 0 ? success(line_item) : success(line_item.reload)
      end
    end
  end
end
