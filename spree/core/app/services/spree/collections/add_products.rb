module Spree
  module Collections
    class AddProducts
      prepend Spree::ServiceModule::Base

      # Adds the given products to the given collections (manual curation), in bulk.
      #
      # @param collections [Array<Spree::Collection>]
      # @param products [Array<Spree::Product>]
      # @return [Spree::ServiceModule::Base::Result]
      def call(collections:, products:)
        return if collections.blank? || products.blank?

        collection_ids = collections.pluck(:id)
        # Every collection's current size in one grouped count, rather than a
        # probe per collection for the position to append at.
        positions = Spree::ProductCollection.where(collection_id: collection_ids).group(:collection_id).count

        product_collections_params = collection_ids.flat_map do |collection_id|
          position = positions.fetch(collection_id, 0)

          products.pluck(:id).map do |product_id|
            {
              collection_id: collection_id,
              product_id: product_id,
              position: (position += 1),
              created_at: Time.current,
              updated_at: Time.current
            }
          end
        end
        Spree::ProductCollection.insert_all(product_collections_params)

        product_ids = products.pluck(:id)
        Spree::Collection.reset_products_counts(collection_ids)
        Spree::Product.reset_collections_counts(product_ids)

        Spree::Product.where(id: product_ids).touch_all
        products.each(&:enqueue_search_index)
        Spree::Collection.where(id: collection_ids).touch_all

        success(true)
      end
    end
  end
end
