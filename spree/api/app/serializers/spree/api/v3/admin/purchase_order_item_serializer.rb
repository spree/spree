module Spree
  module Api
    module V3
      module Admin
        # One SKU on a purchase order, with the price the merchant agreed to.
        class PurchaseOrderItemSerializer < V3::BaseSerializer
          typelize quantity_ordered: :number,
                   quantity_received: :number,
                   quantity_rejected: :number,
                   quantity_over: :number,
                   outstanding: :number,
                   currency: 'string | null',
                   purchase_order_id: 'string | null',
                   thumbnail_url: 'string | null',
                   product_id: 'string | null',
                   variant_id: 'string | null',
                   variant_name: 'string | null',
                   variant_sku: 'string | null',
                   options_text: 'string | null'

          attributes :quantity_ordered, :quantity_received, :quantity_rejected, :quantity_over,
                     :outstanding, :currency,
                     created_at: :iso8601, updated_at: :iso8601

          money_attributes :unit_cost, unit_price: true
          money_attributes :total_cost
          typelize unit_cost: [:string, nullable: false],
                   total_cost: [:string, nullable: false]

          attribute :purchase_order_id do |item|
            Spree::PurchaseOrder.prefixed_id_for(item.purchase_order_id)
          end

          prefixed_id_attributes :variant

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
