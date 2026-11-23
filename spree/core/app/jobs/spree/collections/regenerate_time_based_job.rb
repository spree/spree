module Spree
  module Collections
    # Re-evaluates automatic collections whose rules are time-relative (e.g. AvailableOn),
    # which event-driven regeneration can't keep fresh. Scheduled by the host app
    # (sidekiq-cron / solid_queue recurring), the same pattern as Spree::StockReservations::ExpireJob.
    class RegenerateTimeBasedJob < ::Spree::BaseJob
      queue_as Spree.queues.collections

      def perform
        types = Rails.application.config.spree.time_based_collection_rules.map(&:to_s)

        # Only live stores: a soft-deleted store has no storefront to keep
        # fresh, and its collections can no longer load their store (the
        # association skips deleted rows), so regenerating them would crash
        # on every run until the store is hard deleted.
        time_based = Spree::Collection.automatic.
                     where(store_id: Spree::Store.select(:id)).
                     where(id: Spree::CollectionRule.where(type: types).select(:collection_id))

        each_store_of(time_based) do |collections|
          collections.find_each { |collection| Spree::Collections::RegenerateProducts.call(collection: collection) }
        end
      end
    end
  end
end
