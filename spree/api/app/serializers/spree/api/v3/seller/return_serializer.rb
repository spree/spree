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

          attributes refunded_total: :string
          # What the refund dialog opens on — never more than this may be
          # given back, whatever amount is typed.
          attributes refundable_total: :string, display_refunded_total: :string
          many :return_line_items,
               resource: proc { Spree.api.seller_return_line_item_serializer },
               if: proc { expand?('return_line_items') }

          one :reason, resource: proc { Spree.api.seller_reason_serializer }, if: proc { expand?('reason') }
        end
      end
    end
  end
end
