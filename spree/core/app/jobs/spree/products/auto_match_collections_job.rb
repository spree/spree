module Spree
  module Products
    class AutoMatchCollectionsJob < ::Spree::BaseJob
      queue_as Spree.queues.collections

      def perform(product_id)
        product = Spree::Product.find_by(id: product_id)
        return unless product.present?

        Rails.cache.delete(Spree::Product.auto_match_collections_pending_key(product.store_id, product.id))
        product.reload
        Spree::Products::AutoMatchCollections.call(product: product)
      end
    end
  end
end
