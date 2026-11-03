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

      # Feeds are quoted in the store's currency, so they speak for its
      # default market and leave out what that market may not buy.
      def products
        store.products.active.available_in_market(store.default_market)
      end
    end
  end
end
