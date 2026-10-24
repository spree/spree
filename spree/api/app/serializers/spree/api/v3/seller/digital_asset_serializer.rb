# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # A downloadable file on a seller's own product. Leaves out the
        # provider's settings: they configure the operator's own systems, not
        # the seller's listing.
        class DigitalAssetSerializer < V3::DigitalAssetSerializer
          include Spree::Api::V3::DigitalAssetDetails
        end
      end
    end
  end
end
