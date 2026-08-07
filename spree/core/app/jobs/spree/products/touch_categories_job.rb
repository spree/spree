module Spree
  module Products
    class TouchCategoriesJob < ::Spree::BaseJob
      queue_as Spree.queues.categories

      # @param category_ids [Array<Integer>]
      # @param _legacy_taxonomy_ids [Array<Integer>] ignored; accepted so jobs
      #   enqueued before 6.0 stopped touching taxonomies still deserialize.
      #   Removed in 6.1.
      def perform(category_ids, _legacy_taxonomy_ids = nil)
        Spree::Category.where(id: category_ids).update_all(updated_at: Time.current)
      end
    end
  end
end
