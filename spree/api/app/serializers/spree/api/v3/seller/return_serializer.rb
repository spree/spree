# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # A return on one of this seller's orders.
        #
        # Built on the shared V3 serializer rather than the admin one, which
        # expands the order and the customer behind it — a seller reads their
        # own order's goods coming back, never the buyer's record.
        #
        # What it adds over the shared one is the pair of figures a seller
        # needs to settle: what has already gone back, and what may still.
        class ReturnSerializer < V3::ReturnSerializer
          typelize memo: [:string, nullable: true],
                   stock_location_id: [:string, nullable: true],
                   refunded_total: :string,
                   refundable_total: :string,
                   display_refunded_total: :string

          attributes :memo

          prefixed_id_attributes :stock_location

          string_attributes :refunded_total

          # What the refund dialog opens on — never more than this may be
          # given back, whatever amount is typed.
          string_attributes :refundable_total, :display_refunded_total

          expandable :many, :return_line_items, :seller_return_line_item_serializer

          expandable :one, :reason, :seller_reason_serializer
        end
      end
    end
  end
end
