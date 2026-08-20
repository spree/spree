# frozen_string_literal: true

module Spree
  module SellerRequirements
    # The seller has listed something. A marketplace that admits sellers with
    # an empty catalog fills its storefront with shops that sell nothing.
    class MinimumProducts < Spree::SellerRequirement
      preference :minimum_count, :integer, default: 1

      def met_by_seller?(seller)
        minimum = preferred_minimum_count.to_i
        return true if minimum <= 0

        # The seller's memoized count: the operator's list already pays for
        # it once per row, so this reads that rather than counting again.
        seller.products_count >= minimum
      end
    end
  end
end
