module Spree
  module Carts
    # @deprecated Removing an item is an upsert with quantity zero. Call
    #   Spree::Carts::UpsertItems so the removal passes the same
    #   'carts.upsert_items.validate' hook every other item mutation does.
    #   Removed in Spree 6.1.
    class RemoveLineItem
      prepend Spree::ServiceModule::Base

      def call(cart: nil, order: nil, line_item: nil, options: nil)
        Spree::Deprecation.warn(
          'Spree::Carts::RemoveLineItem is deprecated and will be removed in Spree 6.1. ' \
          'Use Spree::Carts::UpsertItems with quantity: 0 instead.'
        )
        cart ||= order

        result = Spree.cart_upsert_items_workflow.call(
          cart: cart,
          items: [{ variant_id: line_item.variant_id, quantity: 0 }]
        )

        result.success? ? success(line_item) : failure(line_item, result.error)
      end
    end
  end
end
