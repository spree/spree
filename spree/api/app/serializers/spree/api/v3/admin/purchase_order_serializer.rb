module Spree
  module Api
    module V3
      module Admin
        # Goods bought from a supplier. Admin-only — a purchase order is what
        # the merchant owes and expects, which no customer ever sees.
        class PurchaseOrderSerializer < V3::BaseSerializer
          typelize number: :string,
                   status: :string,
                   currency: :string,
                   reference: 'string | null',
                   notes: 'string | null',
                   supplier_id: 'string | null',
                   destination_location_id: 'string | null',
                   expected_at: 'string | null',
                   cancel_by: 'string | null',
                   closed_short_at: 'string | null',
                   close_reason: 'string | null',
                   closed_short: :boolean,
                   items_count: :number,
                   quantity_rejected_total: :number,
                   quantity_ordered_total: :number,
                   quantity_received_total: :number,
                   subtotal: :string,
                   display_subtotal: :string,
                   editable: :boolean,
                   ordered_at: 'string | null',
                   received_at: 'string | null',
                   metadata: 'Record<string, unknown>'

          attributes :number, :status, :currency, :reference, :notes, :metadata, :close_reason,
                     :items_count, :quantity_received_total, :quantity_rejected_total,
                     ordered_at: :iso8601, received_at: :iso8601, closed_short_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          # A calendar date, not an instant: the day a supplier promised, which
          # means the same day in every timezone. `yyyy-mm-dd`, which is what
          # the dashboard's date-only picker both sends and reads. The
          # `:iso8601` type is for instants and would ask a Date for
          # millisecond precision it has no argument for.
          attribute :expected_at do |purchase_order|
            purchase_order.expected_at&.iso8601
          end

          # The day after which the merchant no longer wants the goods — a
          # date for the same reason.
          attribute :cancel_by do |purchase_order|
            purchase_order.cancel_by&.iso8601
          end

          attribute :closed_short, &:closed_short?

          # Named for the merchant's own vocabulary — a purchase order orders,
          # a transfer ships — over the concern's neutral `quantity_expected`.
          attribute :quantity_ordered_total, &:quantity_expected_total

          attribute :editable, &:editable?

          attribute :subtotal do |purchase_order|
            purchase_order.subtotal.to_s
          end

          attribute :display_subtotal do |purchase_order|
            purchase_order.display_subtotal.to_s
          end

          attribute :supplier_id do |purchase_order|
            purchase_order.supplier&.prefixed_id
          end

          attribute :destination_location_id do |purchase_order|
            purchase_order.destination_location&.prefixed_id
          end

          many :items,
               resource: proc { Spree.api.admin_purchase_order_item_serializer },
               if: proc { expand?('items') }

          many :stock_receipts,
               resource: proc { Spree.api.admin_stock_receipt_serializer },
               if: proc { expand?('stock_receipts') }

          one :supplier,
              resource: proc { Spree.api.admin_supplier_serializer },
              if: proc { expand?('supplier') }

          one :destination_location,
              resource: proc { Spree.api.admin_stock_location_serializer },
              if: proc { expand?('destination_location') }
        end
      end
    end
  end
end
