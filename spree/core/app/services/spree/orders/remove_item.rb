module Spree
  module Orders
    # Draft-order twin of the cart item-removal service — see Orders::AddItem.
    class RemoveItem < Spree::Carts::RemoveItem
      def call(order: nil, **kwargs)
        super(cart: order, **kwargs)
      end
    end
  end
end
