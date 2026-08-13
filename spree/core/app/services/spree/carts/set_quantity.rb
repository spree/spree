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

        result = Spree.cart_upsert_items_workflow.call(
          cart: cart,
          items: [{ variant_id: line_item.variant_id, quantity: quantity }]
        )

        result.success? ? success(line_item.reload) : failure(line_item, result.error)
      end
    end
  end
end
