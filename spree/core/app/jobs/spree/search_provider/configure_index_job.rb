module Spree
  module SearchProvider
    # Pushes a store's index settings (filterable, sortable and searchable
    # attributes) to the search provider. Enqueued when they change, so
    # indexing a product never has to push or wait for them.
    class ConfigureIndexJob < Spree::BaseJob
      queue_as Spree.queues.search

      # One push per store at a time; later ones wait their turn rather than
      # being dropped, so the last push always carries the newest settings.
      # Solid Queue-specific (no-op on other adapters).
      limits_concurrency to: 1, key: ->(store_id) { store_id }, duration: 5.minutes if respond_to?(:limits_concurrency)

      retry_on StandardError, wait: :polynomially_longer, attempts: 5
      # Must come after `retry_on StandardError` so DeserializationError lands in discard
      # (ActiveJob handler lookup is reverse-declaration-order).
      discard_on ActiveJob::DeserializationError

      # @param store_id [String] always pass as string for UUID support
      def perform(store_id)
        store = Spree::Store.find_by(id: store_id)
        return unless store

        Spree.search_provider.constantize.new(store).ensure_index_settings!
      end
    end
  end
end
