module Spree
  module Exports
    class NewsletterSubscribers < Spree::Export
      def scope_includes
        [:user, { metafields: :metafield_definition }]
      end

      def csv_headers
        Spree::CSV::NewsletterSubscriberPresenter::HEADERS + metafields_headers
      end
    end
  end
end
