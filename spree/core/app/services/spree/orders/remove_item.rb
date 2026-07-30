module Spree
  module Orders
    # Draft-order twin of the cart service — order: is the canonical keyword
    # on this side, delegating onto the shared implementation.
    class RemoveItem
      prepend Spree::ServiceModule::Base

      def call(order:, variant:, quantity: nil, options: {})
        Spree::Carts::RemoveItem.call(cart: order, variant: variant, quantity: quantity, options: options)
      end
    end
  end
end
