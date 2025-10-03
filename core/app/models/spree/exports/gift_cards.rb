module Spree
  module Exports
    class GiftCards < Spree::Export
      def scope_includes
        [:user, { metafields: :metafield_definition }]
      end

      def csv_headers
        Spree::CSV::GiftCardPresenter::HEADERS + metafields_headers
      end
    end
  end
end
