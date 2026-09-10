module Spree
  module CSV
    # One purchase order line as a CSV row, with its order's header alongside.
    # The first columns match the import schema, so an exported file re-imports.
    class PurchaseOrderItemPresenter
      HEADERS = %w[
        reference supplier destination sku quantity unit_cost currency expected_at cancel_by notes
        number status product_name received rejected
      ].freeze

      def initialize(item)
        @item = item
      end

      attr_reader :item

      def call
        order = item.purchase_order

        [
          order.reference,
          order.supplier&.name,
          order.destination_location&.name,
          item.variant&.sku,
          item.quantity_ordered,
          amount_string(item.unit_cost, order.currency),
          order.currency,
          order.expected_at&.iso8601,
          order.cancel_by&.iso8601,
          order.notes,
          order.number,
          order.status,
          item.variant&.product&.name,
          item.quantity_received,
          item.quantity_rejected
        ]
      end

      private

      def amount_string(amount, currency)
        return nil if amount.nil?

        format("%.#{Spree::Money::Rounding.precision(currency)}f", amount)
      end
    end
  end
end
