module Spree
  module Api
    module V3
      module Admin
        # One SKU on a purchase order, with the price the merchant agreed to.
        class PurchaseOrderItemSerializer < V3::BaseSerializer
          typelize quantity_ordered: :number,
                   quantity_received: :number,
                   outstanding: :number,
                   unit_cost: :string,
                   display_unit_cost: :string,
                   total_cost: :string,
                   display_total_cost: :string,
                   currency: 'string | null',
                   purchase_order_id: 'string | null',
                   variant_id: 'string | null',
                   variant_name: 'string | null',
                   variant_sku: 'string | null',
                   options_text: 'string | null'

          attributes :quantity_ordered, :quantity_received, :outstanding, :currency,
                     created_at: :iso8601, updated_at: :iso8601

          # Money on the wire is a decimal string: a float would round the
          # merchant's own figure.
          attribute :unit_cost do |item|
            item.unit_cost&.to_s
          end

          attribute :total_cost do |item|
            item.total_cost.to_s
          end

          attribute :display_unit_cost do |item|
            item.display_unit_cost.to_s
          end

          attribute :display_total_cost do |item|
            item.display_total_cost.to_s
          end

          attribute :purchase_order_id do |item|
            Spree::PurchaseOrder.prefixed_id_for(item.purchase_order_id)
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

          attribute :options_text do |item|
            item.variant&.options_text
          end
        end
      end
    end
  end
end
