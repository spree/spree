module Spree
  module Exports
    class Orders < Spree::Export
      def scope_includes
        [
          :store,
          :payments,
          :shipments,
          { bill_address: [:state, :country] },
          { ship_address: [:state, :country] },
          { line_items: { variant: { product: [:categories] } } },
          { custom_fields: :custom_field_definition }
        ]
      end

      def multi_line_csv?
        true
      end

      def csv_headers
        Spree::CSV::OrderLineItemPresenter::HEADERS + custom_fields_headers
      end
    end
  end
end
