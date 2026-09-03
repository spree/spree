# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # One line of a return. The variant expands through the seller's own
        # variant serializer, so nothing operator-only rides along with it.
        class ReturnLineItemSerializer < V3::ReturnLineItemSerializer
          one :variant, resource: proc { Spree.api.seller_variant_serializer }, if: proc { expand?('variant') }
        end
      end
    end
  end
end
