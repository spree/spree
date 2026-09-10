module Spree
  module Api
    module V3
      module Admin
        # One delivery against a purchase order or a transfer: what the dock
        # counted in, under which packing slip, on which day.
        class StockReceiptSerializer < V3::BaseSerializer
          typelize number: :string,
                   reference: 'string | null',
                   notes: 'string | null',
                   received_at: :string,
                   receivable_type: [:string, enum: %w[purchase_order stock_transfer]],
                   receivable_id: :string,
                   received_by_id: 'string | null',
                   items_count: :number,
                   quantity_accepted_total: :number,
                   quantity_rejected_total: :number,
                   metadata: 'Record<string, unknown>'

          attributes :number, :reference, :notes, :metadata,
                     :quantity_accepted_total, :quantity_rejected_total,
                     received_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

          # The document this delivery was booked against, as the client
          # names it: `purchase_order` or `stock_transfer`.
          attribute :receivable_type do |receipt|
            receipt.receivable_type.demodulize.underscore
          end

          attribute :receivable_id do |receipt|
            receipt.receivable&.prefixed_id
          end

          attribute :received_by_id do |receipt|
            receipt.received_by.try(:prefixed_id)
          end

          attribute :items_count do |receipt|
            receipt.items.size
          end

          many :items,
               resource: proc { Spree.api.admin_stock_receipt_item_serializer },
               if: proc { expand?('items') }
        end
      end
    end
  end
end
