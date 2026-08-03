module Spree
  module Orders
    # Draft-order twin of the cart workflow — order: is the canonical
    # keyword on this side, mapped onto the shared pipeline so cart-only
    # behavior can diverge without branching one implementation.
    class AddItem < Spree::Carts::AddItem
      def perform(order:, **rest)
        super(cart: order, **rest)
      end
    end
  end
end
