module Spree
  module Orders
    # Draft-order twin of the cart workflow — order: is the canonical
    # keyword on this side, mapped onto the shared pipeline so cart-only
    # behavior can diverge without branching one implementation.
    class AddItem < Spree::Carts::AddItem
      def perform(order:, **rest)
        result = super(cart: order, **rest)
        # Placed orders take items through here too, and their payment
        # status is measured against the total that just moved.
        order.update_statuses!
        result
      end
    end
  end
end
