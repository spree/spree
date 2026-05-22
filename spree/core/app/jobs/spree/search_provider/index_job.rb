module Spree
  module SearchProvider
    class IndexJob < Spree::BaseJob
      queue_as Spree.queues.search

      # Search providers are external services (Meilisearch, etc.); a transient 5xx or
      # network blip should not drop the index update.
      retry_on StandardError, wait: :polynomially_longer, attempts: 5
      # Must come after `retry_on StandardError` so DeserializationError lands in discard
      # (ActiveJob handler lookup is reverse-declaration-order).
      discard_on ActiveJob::DeserializationError

      # @param resource_class [String] e.g. 'Spree::Product'
      # @param resource_id [String] always pass as string for UUID support
      # @param store_id [String] always pass as string for UUID support
      def perform(resource_class, resource_id, store_id)
        resource = resource_class.constantize.find_by(id: resource_id)
        store = Spree::Store.find_by(id: store_id)
        return unless resource && store

        provider = Spree.search_provider.constantize.new(store)
        provider.index(resource)
      end
    end
  end
end
