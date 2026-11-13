module Spree
  module SearchProvider
    # Pushes a store's index settings, then rebuilds its product documents in
    # batches. Enqueued when a custom field definition changes what the index
    # holds, so indexing a product never has to push or wait for settings.
    class ReindexJob < Spree::BaseJob
      queue_as Spree.queues.search

      # One reindex per store at a time; later ones wait their turn rather
      # than being dropped, so the last one always reflects the newest
      # definitions. Solid Queue-specific (no-op on other adapters).
      limits_concurrency to: 1, key: ->(store_id) { store_id }, duration: 1.hour if respond_to?(:limits_concurrency)

      retry_on StandardError, wait: :polynomially_longer, attempts: 5
      # Must come after `retry_on StandardError` so DeserializationError lands in discard
      # (ActiveJob handler lookup is reverse-declaration-order).
      discard_on ActiveJob::DeserializationError

      # @param store_id [String] always pass as string for UUID support
      def perform(store_id)
        store = Spree::Store.find_by(id: store_id)
        return unless store

        # Scoped, so the index is updated in place rather than cleared first.
        Spree.search_provider.constantize.new(store).reindex(store.products)
      end
    end
  end
end
