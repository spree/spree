module Spree
  module SearchProvider
    class IndexJob < Spree::BaseJob
      queue_as Spree.queues.search

      # A bulk write (CSV import, sample data) enqueues thousands of these at
      # once; run in parallel they flood the search service with requests and
      # it answers 429 Too Many Requests. Run one search job per store at a
      # time; the rest wait as blocked executions, so no update is lost. Shared
      # with RemoveJob. The duration only has to outlive one job; expiry lifts
      # the cap, it doesn't drop jobs. Solid Queue only (no-op elsewhere).
      if respond_to?(:limits_concurrency)
        limits_concurrency to: 1, key: ->(_resource_class, _resource_id, store_id) { store_id }, group: 'spree_search_provider', duration: 5.minutes
      end

      # Search providers are external services (Meilisearch, etc.); a transient 5xx or
      # network blip should not drop the index update.
      retry_on StandardError, wait: :polynomially_longer, attempts: 5
      # Must come after `retry_on StandardError` so DeserializationError lands in discard
      # (ActiveJob handler lookup is reverse-declaration-order).
      discard_on ActiveJob::DeserializationError

      # Bulk writers enqueue this inside their transaction; run before it
      # commits, the job would index the product's previous prices.
      self.enqueue_after_transaction_commit = true

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
