module Spree
  module Orders
    # Draft-order twin of the cart item service. Identical mechanics today;
    # exists so cart-only behavior (stock reservations, checkout warnings)
    # and draft-order behavior can diverge without branching one service.
    # Speaks order: on the outside, maps onto the shared cart pipeline.
    class AddItem < Spree::Carts::AddItem
      def call(order: nil, **kwargs)
        super(cart: order, **kwargs)
      end
    end
  end
end
