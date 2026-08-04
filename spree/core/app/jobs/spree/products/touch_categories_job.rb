module Spree
  module Products
    class TouchCategoriesJob < ::Spree::BaseJob
      queue_as Spree.queues.categories

      def perform(category_ids, taxonomy_ids)
        Spree::Category.where(id: category_ids).update_all(updated_at: Time.current)
        Spree::Taxonomy.where(id: taxonomy_ids).update_all(updated_at: Time.current)
      end
    end
  end
end
