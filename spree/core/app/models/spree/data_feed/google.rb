require_dependency 'spree/data_feed'

module Spree
  class DataFeed::Google < DataFeed
    class << self
      def label
        'Google Merchant Center Feed'
      end

      def provider_name
        'google'
      end

      def presenter_class
        Spree::DataFeeds::GooglePresenter
      end
    end
  end
end
