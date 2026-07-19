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

        product_collections_params = collections.pluck(:id).flat_map do |collection_id|
          position = Spree::ProductCollection.where(collection_id: collection_id).count

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

        collection_ids = collections.pluck(:id)
        product_ids = products.pluck(:id)
        collection_ids.each { |id| Spree::Collection.reset_counters(id, :product_collections) }
        product_ids.each { |id| Spree::Product.reset_counters(id, :product_collections) }

        Spree::Product.where(id: product_ids).touch_all
        products.each(&:enqueue_search_index)
        Spree::Collection.where(id: collection_ids).touch_all

        success(true)
      end
    end
  end
end
