module Spree
  module Exports
    class Customers < Spree::Export
      def scope_includes
        [
          { bill_address: :state },
          { ship_address: :state },
          { metafields: :metafield_definition }
        ]
      end

      def csv_headers
        Spree::CSV::CustomerPresenter::HEADERS + metafields_headers
      end
    end
  end
end
