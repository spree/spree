module Spree
  module Products
    class RefreshMetricsJob < Spree::BaseJob
      queue_as Spree.queues.products

      def perform(product_id, store_id)
        publication = Spree::ProductPublication.find_by(product_id: product_id, store_id: store_id)
        return unless publication

        publication.refresh_metrics!
      end
    end
  end
end
