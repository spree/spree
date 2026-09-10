module Spree
  module Api
    module V3
      module Admin
        # One line of a delivery: how many of a document's line arrived, how
        # many were refused, and why.
        class StockReceiptItemSerializer < V3::BaseSerializer
          typelize quantity_accepted: :number,
                   quantity_rejected: :number,
                   rejection_reason: [:string, enum: Spree::StockReceiptItem::REJECTION_REASONS, nullable: true],
                   notes: 'string | null',
                   line_type: [:string, enum: %w[purchase_order_item stock_transfer_item]],
                   line_id: 'string | null',
                   variant_id: 'string | null',
                   variant_name: 'string | null',
                   variant_sku: 'string | null',
                   thumbnail_url: 'string | null'

          attributes :quantity_accepted, :quantity_rejected, :rejection_reason, :notes

          # The document line this delivery counted against, as the client
          # names it: `purchase_order_item` or `stock_transfer_item`.
          attribute :line_type do |item|
            item.line_type.demodulize.underscore
          end

          attribute :line_id do |item|
            item.line&.prefixed_id
          end

          attribute :variant_id do |item|
            item.variant&.prefixed_id
          end

          attribute :variant_name do |item|
            item.variant&.product&.name
          end

          attribute :variant_sku do |item|
            item.variant&.sku
          end

          attribute :thumbnail_url do |item|
            image_url_for(item.line&.thumbnail)
          end
        end
      end
    end
  end
end
