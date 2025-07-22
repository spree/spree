module Spree
  module Exports
    class GiftCards < Spree::Export
      def scope_includes
        [:user]
      end

      def csv_headers
        Spree::CSV::GiftCardPresenter::HEADERS
      end
    end
  end
end