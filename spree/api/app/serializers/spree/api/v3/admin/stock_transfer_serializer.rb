module Spree
  module Api
    module V3
      module Admin
        # Stock moving between two of the merchant's own warehouses. The trip
        # has a middle: `shipped_at` is when the units left the source,
        # `received_at` when the destination finished counting them in.
        class StockTransferSerializer < V3::StockTransferSerializer
          typelize status: :string,
                   notes: 'string | null',
                   items_count: :number,
                   quantity_shipped_total: :number,
                   quantity_received_total: :number,
                   editable: :boolean,
                   metadata: 'Record<string, unknown>'

          attributes :status, :notes, :metadata,
                     :items_count, :quantity_received_total,
                     shipped_at: :iso8601, received_at: :iso8601, deleted_at: :iso8601

          # Named for the merchant's own vocabulary — a transfer ships, a
          # purchase order orders — over the concern's neutral
          # `quantity_expected`.
          attribute :quantity_shipped_total, &:quantity_expected_total

          attribute :editable, &:editable?

          many :items,
               resource: proc { Spree.api.admin_stock_transfer_item_serializer },
               if: proc { expand?('items') }

          one :source_location,
              resource: proc { Spree.api.admin_stock_location_serializer },
              if: proc { expand?('source_location') }

          one :destination_location,
              resource: proc { Spree.api.admin_stock_location_serializer },
              if: proc { expand?('destination_location') }
        end
      end
    end
  end
end
