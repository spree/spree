module Spree
  module Collections
    # Re-evaluates automatic collections whose rules are time-relative (e.g. AvailableOn),
    # which event-driven regeneration can't keep fresh. Scheduled by the host app
    # (sidekiq-cron / solid_queue recurring), the same pattern as Spree::StockReservations::ExpireJob.
    class RegenerateTimeBasedJob < ::Spree::BaseJob
      queue_as Spree.queues.collections

      def perform
        types = Rails.application.config.spree.time_based_collection_rules.map(&:to_s)

        Spree::Collection.automatic.
          where(id: Spree::CollectionRule.where(type: types).select(:collection_id)).
          find_each { |collection| Spree::Collections::RegenerateProducts.call(collection: collection) }
      end
    end
  end
end
