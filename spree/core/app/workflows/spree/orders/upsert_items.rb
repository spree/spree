module Spree
  module Orders
    # Draft-order twin of the cart workflow — order: is the canonical keyword
    # on this side, and hooks dispatch under 'orders.upsert_items.*' so an
    # extension can hold admin edits to different rules than storefront ones.
    #
    # Totals are NOT recalculated here: Spree::Orders::Create and
    # Spree::Orders::Update run items, fulfillments and coupons as one
    # pipeline and recalculate once at the end of it.
    class UpsertItems < Spree::Carts::UpsertItems
      def perform(order:, **rest)
        super(cart: order, **rest)
      end

      private

      def recalculate?
        false
      end

      # A merchant's edit applies whole or not at all — a line silently
      # skipped is worse here than a failed request.
      def partial_success?
        false
      end
    end
  end
end
