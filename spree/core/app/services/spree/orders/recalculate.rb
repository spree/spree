module Spree
  module Orders
    # Draft-order twin of cart recalculation — see Orders::AddItem.
    class Recalculate < Spree::Carts::Recalculate
      def call(order: nil, **kwargs)
        super(cart: order, **kwargs)
      end
    end
  end
end
