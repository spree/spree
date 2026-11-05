module Spree
  module Collections
    class RegenerateProductsJob < ::Spree::BaseJob
      queue_as Spree.queues.collections

      def perform(collection_id)
        Spree::Collections::RegenerateProducts.call(collection: Spree::Collection.find_by(id: collection_id))
      end
    end
  end
end
