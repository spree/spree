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
        return true if ships_own_methods?(seller)

        operator_shares_methods?
      end

      private

      def ships_own_methods?(seller)
        if seller.read_association_in_memory?(:delivery_methods)
          seller.delivery_methods.any?(&:storefront_visible?)
        else
          seller.delivery_methods.storefront_visible.exists?
        end
      end

      # The same answer for every seller of the store, so a list of them
      # asks once.
      def operator_shares_methods?
        return @operator_shares_methods if defined?(@operator_shares_methods)

        @operator_shares_methods = store.delivery_methods.shared_with_sellers.storefront_visible.exists?
      end
    end
  end
end
