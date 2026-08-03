module Spree
  module Orders
    # Order twin of the cart workflow — order: is the canonical keyword on
    # this side (the calculator resolves polymorphically through the
    # model's #updater).
    class RecalculateTotals < Spree::Carts::RecalculateTotals
      def perform(order:)
        super(cart: order)
      end
    end
  end
end
