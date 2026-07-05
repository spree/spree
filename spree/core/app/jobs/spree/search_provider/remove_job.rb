module Spree
  module SearchProvider
    class RemoveJob < Spree::BaseJob
      queue_as Spree.queues.search

      # Search providers are external services; broad retry covers network blips and 5xx.
      retry_on StandardError, wait: :polynomially_longer, attempts: 5
      # Must come after `retry_on StandardError` so DeserializationError lands in discard
      # (ActiveJob handler lookup is reverse-declaration-order).
      discard_on ActiveJob::DeserializationError

      # @param prefixed_id [String] prefixed ID of the document to remove (e.g. 'prod_abc')
      # @param store_id [String] always pass as string for UUID support
      def perform(prefixed_id, store_id)
        store = Spree::Store.find_by(id: store_id)
        return unless store

        provider = Spree.search_provider.constantize.new(store)
        provider.remove_by_id(prefixed_id)
      end
    end
  end
end
