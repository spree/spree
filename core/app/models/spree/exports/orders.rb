module Spree
  module Exports
    class Orders < Spree::Export
      def scope_includes
        [
          :payments,
          :shipments,
          { bill_address: :state },
          { ship_address: :state },
          { line_items: { variant: { product: [:taxons] } } },
          { metafields: :metafield_definition }
        ]
      end

      def multi_line_csv?
        true
      end

      def csv_headers
        Spree::CSV::OrderLineItemPresenter::HEADERS + metafields_headers
      end
    end
  end
end
