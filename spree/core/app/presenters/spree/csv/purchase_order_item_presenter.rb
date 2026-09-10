module Spree
  module CSV
    # One purchase order line as a CSV row: the order it belongs to, then the
    # line, then what has happened to it. Every import-schema column is here
    # under its own name, so an exported file re-imports as it stands.
    class PurchaseOrderItemPresenter
      HEADERS = %w[
        number status reference supplier destination
        sku product_name quantity received rejected unit_cost currency
        expected_at cancel_by notes
      ].freeze

      def initialize(item)
        @item = item
      end

      attr_reader :item

      def call
        order = item.purchase_order

        [
          order.number,
          order.status,
          order.reference,
          order.supplier&.name,
          order.destination_location&.name,
          item.variant&.sku,
          item.variant&.product&.name,
          item.quantity_ordered,
          item.quantity_received,
          item.quantity_rejected,
          amount_string(item.unit_cost, order.currency),
          order.currency,
          order.expected_at&.iso8601,
          order.cancel_by&.iso8601,
          order.notes
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
