module Spree
  module Orders
    # Draft-order twin of the cart service — order: is the canonical keyword
    # on this side, mapped onto the shared pipeline. Exists so cart-only
    # behavior (reservations, checkout warnings) can diverge without
    # branching one implementation.
    class Recalculate < Spree::Carts::Recalculate
      alias_argument order: :cart
    end
  end
end
