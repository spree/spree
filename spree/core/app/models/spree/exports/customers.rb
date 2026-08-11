module Spree
  module Exports
    class Customers < Spree::Export
      def scope_includes
        [
          { bill_address: :state },
          { ship_address: :state },
          { custom_fields: :custom_field_definition }
        ]
      end

      def csv_headers
        Spree::CSV::CustomerPresenter::HEADERS + custom_fields_headers
      end
    end
  end
end
