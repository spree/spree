module Spree
  module Orders
    # Draft-order twin of the cart removal service — see Orders::AddItem.
    class RemoveLineItem < Spree::Carts::RemoveLineItem
      def call(order: nil, **kwargs)
        super(cart: order, **kwargs)
      end
    end
  end
end
