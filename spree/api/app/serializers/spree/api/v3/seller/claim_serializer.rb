# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # A claim on one of this seller's orders.
        #
        # Built on the shared V3 serializer rather than the admin one, which
        # expands the order and the customer behind it.
        class ClaimSerializer < V3::ClaimSerializer
          typelize memo: [:string, nullable: true]

          attributes :memo

          many :claim_line_items,
               resource: proc { Spree.api.seller_claim_line_item_serializer },
               if: proc { expand?('claim_line_items') }

          one :reason, resource: proc { Spree.api.seller_reason_serializer }, if: proc { expand?('reason') }
        end
      end
    end
  end
end
