module Spree
  module Exports
    class NewsletterSubscribers < Spree::Export
      def scope_includes
        [:user]
      end

      def csv_headers
        Spree::CSV::NewsletterSubscriberPresenter::HEADERS
      end
    end
  end
end
