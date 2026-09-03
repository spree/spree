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

          attribute :stock_location_id do |exchange|
            exchange.stock_location&.prefixed_id
          end

          many :exchange_line_items,
               resource: proc { Spree.api.seller_exchange_line_item_serializer },
               if: proc { expand?('exchange_line_items') }

          one :reason, resource: proc { Spree.api.seller_reason_serializer }, if: proc { expand?('reason') }
        end
      end
    end
  end
end
