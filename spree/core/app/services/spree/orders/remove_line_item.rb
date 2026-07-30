module Spree
  module Orders
    # Draft-order twin of the cart service — order: is the canonical keyword
    # on this side, delegating onto the shared implementation.
    class RemoveLineItem
      prepend Spree::ServiceModule::Base

      def call(order:, line_item:, options: {})
        Spree::Carts::RemoveLineItem.call(cart: order, line_item: line_item, options: options)
      end
    end
  end
end
