module Spree
  module Carts
    # @deprecated Removing an item is an upsert with quantity zero. Call
    #   Spree::Carts::UpsertItems so the removal passes the same
    #   'carts.upsert_items.validate' hook every other item mutation does.
    #   Removed in Spree 6.1.
    class RemoveLineItem
      prepend Spree::ServiceModule::Base

      # @param options [Hash] accepted for signature compatibility and ignored —
      #   the upsert path identifies the row by variant, not by line-item options.
      def call(cart: nil, order: nil, line_item: nil, options: nil)
        Spree::Deprecation.warn(
          'Spree::Carts::RemoveLineItem is deprecated and will be removed in Spree 6.1. ' \
          'Use Spree::Carts::UpsertItems with quantity: 0 instead. Note it removes the ' \
          'cart\'s line item for the variant, which is this one unless the cart holds ' \
          'several rows of the same variant.'
        )
        owner = cart || order

        # Draft orders keep the order workflow's all-or-nothing contract;
        # only carts get the warn-and-skip one.
        cart_owned = owner.is_a?(Spree::Cart)
        workflow = (cart_owned ? Spree.cart_upsert_items_workflow : Spree.order_upsert_items_workflow).new
        result = workflow.call(
          **(cart_owned ? { cart: owner } : { order: owner }),
          items: [{ variant_id: line_item.variant_id, quantity: 0 }]
        )

        return failure(line_item, result.error) if result.failure?

        # A :validate handler may have vetoed the removal; on the cart side
        # that is a warning rather than a failed result, but this service's
        # callers expect a failure.
        rejection = workflow.warnings.first
        return failure(line_item, rejection.message) if rejection

        success(line_item)
      end
    end
  end
end
