module Spree
  module DataFeeds
    class BasePresenter
      def initialize(data_feed)
        @data_feed = data_feed
        @store = data_feed.store
      end

      attr_reader :data_feed, :store

      # @return [String] the feed content (XML, CSV, etc.)
      def call
        raise NotImplementedError
      end

      private

      def products
        store.products.active
      end
    end
  end
end
