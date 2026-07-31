module Spree
  module Orders
    # Draft-order twin of the cart workflow — order: is the canonical
    # keyword on this side, mapped onto the shared pipeline.
    class Recalculate < Spree::Carts::Recalculate
      def perform(order:, **rest)
        super(cart: order, **rest)
      end
    end
  end
end
