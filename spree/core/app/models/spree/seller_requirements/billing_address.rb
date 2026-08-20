# frozen_string_literal: true

module Spree
  module SellerRequirements
    # Where the seller is invoiced — what a commission invoice is addressed
    # to, so a marketplace charging commission cannot do without it.
    class BillingAddress < Spree::SellerRequirement
      def met_by_seller?(seller)
        seller.billing_address.present? && seller.billing_address.persisted?
      end
    end
  end
end
