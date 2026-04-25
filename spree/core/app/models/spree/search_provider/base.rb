module Spree
  module SearchProvider
    class Base
      attr_reader :store

      # Whether this provider requires background indexing jobs.
      # Override in subclasses. Database provider returns false.
      def self.indexing_required?
        false
      end

      def initialize(store)
        @store = store
      end

      # Search and paginate products. Does NOT compute filter facets — use #filters for that.
      #
      # @param scope [ActiveRecord::Relation] base scope (store-scoped, visibility-filtered, authorized)
      # @param query [String, nil] text search query
      # @param filters [Hash] structured filters (price_gte, with_option_value_ids, in_category, in_categories, etc.)
      # @param sort [String, nil] sort param (e.g. 'price', '-price', 'best_selling')
      # @param page [Integer] page number
      # @param limit [Integer] results per page
      # @return [SearchResult]
      def search_and_filter(scope:, query: nil, filters: {}, sort: nil, page: 1, limit: 25)
        raise NotImplementedError
      end

      # Compute filter facets, sort options, and total count for the given scope.
      # Called by the dedicated filters endpoint — kept separate from search_and_filter
      # to avoid expensive facet queries on every product listing.
      #
      # @param scope [ActiveRecord::Relation] base scope
      # @param query [String, nil] text search query
      # @param filters [Hash] structured filters
      # @return [FiltersResult]
      def filters(scope:, query: nil, filters: {})
        raise NotImplementedError
      end

      # Index a product — called after product save. No-op for database provider.
      #
      # @param product [Spree::Product] the product to index
      def index(product)
        # no-op by default
      end

      # Remove a product from the index.
      #
      # @param product [Spree::Product] the product to remove
      def remove(product)
        # no-op by default
      end

      # Remove a document from the index by prefixed ID (used when record is already deleted).
      #
      # @param prefixed_id [String] the prefixed ID (e.g. 'prod_abc')
      def remove_by_id(prefixed_id)
        # no-op by default
      end

      # Index a batch of documents. Called by rake task with pre-serialized documents.
      #
      # @param documents [Array<Hash>] serialized product documents
      def index_batch(documents)
        # no-op by default
      end

      # Configure index settings (filterable, sortable, searchable attributes).
      # Called by rake task before indexing. No-op for database provider.
      def ensure_index_settings!
        # no-op by default
      end

      # Bulk reindex — full catalog sync. Called manually or via rake task.
      #
      # @param scope [ActiveRecord::Relation] products to reindex (default: all in store)
      def reindex(scope = nil)
        # no-op by default
      end

      private

      def locale
        Spree::Current.locale || store.default_market&.default_locale || I18n.locale.to_s
      end

      def currency
        Spree::Current.currency || store.default_market&.currency
      end
    end
  end
end
