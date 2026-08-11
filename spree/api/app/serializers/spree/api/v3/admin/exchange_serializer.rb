# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ExchangeSerializer < V3::ExchangeSerializer
          typelize memo: [:string, nullable: true],
                   metadata: 'Record<string, unknown>',
                   stock_location_id: [:string, nullable: true],
                   created_by_id: [:string, nullable: true]

          attributes :memo, :metadata, created_at: :iso8601, updated_at: :iso8601

          attribute :stock_location_id do |exchange|
            exchange.stock_location&.prefixed_id
          end

          attribute :created_by_id do |exchange|
            exchange.created_by&.prefixed_id
          end

          many :exchange_line_items,
               resource: proc { Spree.api.admin_exchange_line_item_serializer },
               if: proc { expand?('exchange_line_items') }

          one :reason, resource: proc { Spree.api.admin_return_reason_serializer }, if: proc { expand?('reason') }
          one :order, resource: proc { Spree.api.admin_order_serializer }, if: proc { expand?('order') }
          one :stock_location, resource: proc { Spree.api.admin_stock_location_serializer }, if: proc { expand?('stock_location') }
          many :refunds, resource: proc { Spree.api.admin_refund_serializer }, if: proc { expand?('refunds') }
        end
      end
    end
  end
end
