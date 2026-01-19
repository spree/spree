module Spree
  module Products
    class RefreshMetricsJob < Spree::BaseJob
      queue_as Spree.queues.products

      def perform(product_id, store_id)
        store_product = Spree::StoreProduct.find_by(product_id: product_id, store_id: store_id)
        return unless store_product

        store_product.refresh_metrics!
      end
    end
  end
end
