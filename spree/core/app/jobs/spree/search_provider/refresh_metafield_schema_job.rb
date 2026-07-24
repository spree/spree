# frozen_string_literal: true

module Spree
  module SearchProvider
    class RefreshMetafieldSchemaJob < Spree::BaseJob
      queue_as Spree.queues.search

      # Search providers are external services (Meilisearch, etc.); a transient 5xx or
      # network blip should not prevent refreshing index settings.
      retry_on StandardError, wait: :polynomially_longer, attempts: 5

      # Clears cached metafield definitions and ensures each store's search index
      # settings are updated to reflect the latest searchable/sortable attributes.
      def perform
        Spree::Dependencies.search_metafield_attributes_class.clear_cache!

        provider = Spree.search_provider.constantize
        return unless provider.indexing_required?

        Spree::Store.find_each do |store|
          provider.new(store).ensure_index_settings!
        end
      end
    end
  end
end
