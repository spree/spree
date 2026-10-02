# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # An exchange on one of this seller's orders.
        #
        # Built on the shared V3 serializer rather than the admin one, which
        # expands the order and the customer behind it.
        class ExchangeSerializer < V3::ExchangeSerializer
          typelize memo: [:string, nullable: true],
                   stock_location_id: [:string, nullable: true]

          attributes :memo

          prefixed_id_attributes :stock_location

          expandable :many, :exchange_line_items, :seller_exchange_line_item_serializer

          expandable :one, :reason, :seller_reason_serializer
        end
      end
    end
  end
end
