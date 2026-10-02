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
                   quantity_rejected_total: :number,
                   editable: :boolean,
                   closed_short_at: 'string | null',
                   close_reason: 'string | null',
                   closed_short: :boolean,
                   shipped_at: 'string | null',
                   received_at: 'string | null',
                   deleted_at: 'string | null',
                   metadata: 'Record<string, unknown>'

          attributes :status, :notes, :metadata, :close_reason,
                     :items_count, :quantity_received_total, :quantity_rejected_total,
                     shipped_at: :iso8601, received_at: :iso8601, closed_short_at: :iso8601,
                     deleted_at: :iso8601

          attribute :closed_short, &:closed_short?

          # Named for the merchant's own vocabulary — a transfer ships, a
          # purchase order orders — over the concern's neutral
          # `quantity_expected`.
          attribute :quantity_shipped_total, &:quantity_expected_total

          attribute :editable, &:editable?

          expandable :many, :items, :admin_stock_transfer_item_serializer

          expandable :many, :stock_receipts, :admin_stock_receipt_serializer

          expandable :one, :source_location, :admin_stock_location_serializer

          expandable :one, :destination_location, :admin_stock_location_serializer
        end
      end
    end
  end
end
