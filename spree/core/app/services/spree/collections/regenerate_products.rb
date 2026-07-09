module Spree
  module Collections
    class RegenerateProducts
      prepend ::Spree::ServiceModule::Base

      # Rebuilds a collection's materialized ProductCollection membership from its rules.
      #
      # @param collection [Spree::Collection]
      # @return [Spree::ServiceModule::Base::Result]
      def call(collection:)
        return if collection.nil?
        return if collection.destroyed?
        return if collection.manual?

        previous_products_ids = collection.product_collections.order(position: :asc).pluck(:product_id)

        # Hard-delete the join rows (no callbacks). Class-level delete on the collection
        # scope rather than the association proxy, which under `dependent: :destroy_async`
        # doesn't reliably remove rows here.
        Spree::ProductCollection.where(collection_id: collection.id).delete_all

        products_matching_rules = collection.products_matching_rules
        product_ids_to_insert = products_matching_rules.ids

        previous_filtered_products_ids = previous_products_ids & product_ids_to_insert
        max_products_position = previous_filtered_products_ids.size || 0

        if product_ids_to_insert.any?
          records_to_insert = product_ids_to_insert.map do |product_id|
            position = previous_filtered_products_ids.index(product_id)
            position = position.present? ? position + 1 : max_products_position += 1

            product_collection_attributes(product_id, collection, position)
          end

          Spree::ProductCollection.insert_all(records_to_insert)

          # expire product cache + reindex
          products = Spree::Product.where(id: (previous_products_ids + product_ids_to_insert).uniq)
          products.touch_all
          products.each(&:enqueue_search_index)
        end

        # counter caches — bulk insert/delete bypass the ProductCollection counter_cache callbacks
        Spree::Collection.reset_counters(collection.id, :product_collections)
        all_product_ids = (previous_products_ids + product_ids_to_insert).uniq
        existing_product_ids = Spree::Product.where(id: all_product_ids).pluck(:id)
        existing_product_ids.each { |id| Spree::Product.reset_counters(id, :product_collections) }

        success(collection)
      end

      private

      def product_collection_attributes(product_id, collection, position)
        {
          product_id: product_id,
          collection_id: collection.id,
          position: position,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
    end
  end
end
