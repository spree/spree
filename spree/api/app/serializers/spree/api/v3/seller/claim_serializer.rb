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

          expandable :many, :claim_line_items, :seller_claim_line_item_serializer

          expandable :one, :reason, :seller_reason_serializer
        end
      end
    end
  end
end
