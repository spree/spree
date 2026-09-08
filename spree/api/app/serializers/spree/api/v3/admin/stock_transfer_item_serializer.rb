module Spree
  module Api
    module V3
      module Admin
        # One SKU on a stock transfer: how many left, how many arrived, and
        # what happened to the difference.
        class StockTransferItemSerializer < V3::BaseSerializer
          typelize quantity_shipped: :number,
                   quantity_received: :number,
                   outstanding: :number,
                   discrepancy_reason: 'string | null',
                   stock_transfer_id: 'string | null',
                   thumbnail_url: 'string | null',
                   product_id: 'string | null',
                   variant_id: 'string | null',
                   variant_name: 'string | null',
                   variant_sku: 'string | null',
                   options_text: 'string | null'

          attributes :quantity_shipped, :quantity_received, :outstanding, :discrepancy_reason,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :stock_transfer_id do |item|
            Spree::StockTransfer.prefixed_id_for(item.stock_transfer_id)
          end

          attribute :variant_id do |item|
            item.variant&.prefixed_id
          end

          # The product the line's variant belongs to, so a line can link
          # straight to the screen where that SKU's stock lives.
          attribute :product_id do |item|
            item.variant&.product&.prefixed_id
          end

          attribute :variant_name do |item|
            item.variant&.product&.name
          end

          attribute :variant_sku do |item|
            item.variant&.sku
          end

          attribute :options_text do |item|
            item.variant&.options_text
          end

          attribute :thumbnail_url do |item|
            image_url_for(item.thumbnail)
          end
        end
      end
    end
  end
end
