# frozen_string_literal: true

module Spree
  module SellerRequirements
    # Where customer returns go. Without it a shopper cannot be told where to
    # send anything back, which is why most marketplaces ask for it up front.
    class ReturnsAddress < Spree::SellerRequirement
      def met_by_seller?(seller)
        seller.returns_address.present? && seller.returns_address.persisted?
      end
    end
  end
end
