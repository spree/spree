module Spree
  module Exports
    class GiftCards < Spree::Export
      def scope_includes
        [:user, { custom_fields: :custom_field_definition }]
      end

      def csv_headers
        Spree::CSV::GiftCardPresenter::HEADERS + custom_fields_headers
      end
    end
  end
end
