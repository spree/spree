# frozen_string_literal: true

module Spree
  module SellerRequirements
    # The seller has at least one way to ship. Without one their goods quote
    # no rates at checkout, so the listing looks live and cannot be bought.
    #
    # Satisfied either way a marketplace can be run
    # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13): the seller
    # created a method of their own, or the operator ships for everyone and
    # has shared at least one of theirs.
    class DeliveryMethod < Spree::SellerRequirement
      def met_by_seller?(seller)
        return true if seller.delivery_methods.storefront_visible.exists?

        store.delivery_methods.shared_with_sellers.storefront_visible.exists?
      end
    end
  end
end
