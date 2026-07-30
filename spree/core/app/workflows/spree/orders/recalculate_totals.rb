module Spree
  module Orders
    # Order twin of the cart service — order: is the canonical keyword on
    # this side, mapped onto the shared flow (the calculator resolves
    # polymorphically through the model's #updater).
    class RecalculateTotals < Spree::Carts::RecalculateTotals
      alias_argument order: :cart
    end
  end
end
