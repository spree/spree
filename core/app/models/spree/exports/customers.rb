module Spree
  module Exports
    class Customers < Spree::Export
      def scope_includes
        [
          { bill_address: :state },
          { ship_address: :state },
        ]
      end

      def csv_headers
        Spree::CSV::CustomerPresenter::HEADERS
      end
    end
  end
end
