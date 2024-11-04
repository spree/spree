module Spree
  module Exports
    class Orders < Spree::Export
      def scope_includes
        [
          :payments,
          :shipments,
          { bill_address: :state },
          { ship_address: :state },
          { line_items: { variant: { product: [:taxons] } } }
        ]
      end

      def multi_line_csv?
        true
      end

      def csv_headers
        Spree::CSV::OrderLineItemPresenter::HEADERS
      end
    end
  end
end
