# frozen_string_literal: true

module Spree
  module SellerRequirements
    # Where customer returns go. Without it a shopper cannot be told where to
    # send anything back, which is why most marketplaces ask for it up front.
    #
    # Satisfied by a stock location rather than a loose address: a received
    # return has to restock somewhere the catalog can see, so the address on
    # its own would leave the goods arriving nowhere (Decision 12).
    class ReturnsAddress < Spree::SellerRequirement
      def met_by_seller?(seller)
        # Boolean rather than the bare `&.`: `satisfied?` is public API and
        # sibling kinds all answer true or false.
        seller.returns_location&.postable? == true
      end
    end
  end
end
