module Spree
  module SearchProvider
    # Pushes a store's index settings, then rebuilds its product documents in
    # batches. Enqueued when a custom field definition changes what the index
    # holds, so indexing a product never has to push or wait for settings.
    #
    # On ActiveJob Continuations: the cursor is the last product id indexed,
    # so a retry or a deploy mid-run resumes there instead of re-sending the
    # whole catalog. Documents are upserted, never cleared first, so
    # re-sending the batch that was in flight changes nothing.
    class ReindexJob < Spree::BaseJob
      include ActiveJob::Continuable

      queue_as Spree.queues.search

      BATCH_SIZE = 500

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
        # Outside the steps on purpose: runs on every execution, resumes included.
        @store = Spree::Store.find_by(id: store_id)
        return unless @store

        provider_class = Spree.search_provider.constantize
        return unless provider_class.indexing_required?

        @provider = provider_class.new(@store)

        step :push_settings
        step :index_products, start: 0
      end

      private

      def push_settings
        @provider.ensure_index_settings!
      end

      def index_products(step)
        loop do
          products = @store.products.where(Spree::Product.arel_table[:id].gt(step.cursor)).
                     reorder(:id).limit(BATCH_SIZE).preload_associations_lazily.to_a
          break if products.empty?

          @provider.index_batch(products.flat_map { |product| product.search_presentation(@store) })
          step.set!(products.last.id)
        end
      end
    end
  end
end
