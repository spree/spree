module Spree
  module SearchProvider
    # Pushes a store's index settings, then rebuilds its product documents in
    # batches. Enqueued when a custom field definition changes what the index
    # holds, so indexing a product never has to push or wait for settings,
    # and with +clear: true+ for a new index, whose documents written before
    # its settings existed may be stale: clearing it first leaves only what
    # the rebuild sends.
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
      limits_concurrency to: 1, key: ->(store_id, *) { store_id }, duration: 1.hour if respond_to?(:limits_concurrency)

      retry_on StandardError, wait: :polynomially_longer, attempts: 5
      # Must come after `retry_on StandardError` so DeserializationError lands in discard
      # (ActiveJob handler lookup is reverse-declaration-order).
      discard_on ActiveJob::DeserializationError

      # @param store_id [String] always pass as string for UUID support
      # @param clear [Boolean] remove every document before rebuilding
      def perform(store_id, clear: false)
        # Outside the steps on purpose: runs on every execution, resumes included.
        @store = Spree::Store.find_by(id: store_id)
        return unless @store

        provider_class = Spree.search_provider.constantize
        return unless provider_class.indexing_required?

        @provider = provider_class.new(@store)

        step :push_settings
        step :clear_index if clear
        step :index_products
      end

      private

      def push_settings
        @provider.ensure_index_settings!
      end

      def clear_index
        @provider.clear_index
      end

      def index_products(step)
        loop do
          # No cursor on the first batch: a literal 0 cannot be compared with a UUID id.
          products = @store.products.reorder(:id).limit(BATCH_SIZE).preload_associations_lazily
          products = products.where(Spree::Product.arel_table[:id].gt(step.cursor)) if step.cursor
          products = products.to_a
          break if products.empty?

          @provider.index_batch(products.flat_map { |product| product.search_presentation(@store) })
          step.set!(products.last.id)
        end
      end
    end
  end
end
