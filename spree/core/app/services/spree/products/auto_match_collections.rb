module Spree
  module Products
    class AutoMatchCollections
      prepend ::Spree::ServiceModule::Base

      # Re-evaluates a product's membership in the automatic collections of its store —
      # removing it from collections it no longer matches and adding it to ones it now does.
      #
      # @param product [Spree::Product]
      # @return [Spree::ServiceModule::Base::Result]
      def call(product:)
        return unless product.present?

        collections_to_remove = []
        collections_to_add = []

        # existing memberships that no longer match (tags/prices changed)
        product.collections.automatic.includes(:rules).each do |collection|
          collections_to_remove << collection unless collection.products_matching_rules.ids.include?(product.id)
        end

        if collections_to_remove.any?
          Spree::ProductCollection.where(collection: collections_to_remove, product: product).delete_all
        end

        # automatic collections in the product's store that it now matches
        Spree::Collection.automatic.where(store_id: product.store_id).includes(:rules, :products).each do |collection|
          collections_to_add << collection if collection.products.exclude?(product) && collection.products_matching_rules.ids.include?(product.id)
        end

        if collections_to_add.any?
          products_counts = Spree::Collection.where(id: collections_to_add.pluck(:id)).
                            joins(:product_collections).
                            reorder('').
                            group(:collection_id).
                            count(:product_id)

          Spree::ProductCollection.insert_all(
            collections_to_add.map do |collection|
              position = products_counts[collection.id].to_i + 1
              product_collection_attributes(collection, product, position)
            end
          )
        end

        all_affected = (collections_to_remove + collections_to_add).uniq

        if all_affected.any?
          affected_ids = all_affected.pluck(:id)
          Spree::Collection.where(id: affected_ids).touch_all
          product.touch
          product.enqueue_search_index

          # counter caches — bulk insert/delete bypass the counter_cache callbacks
          affected_ids.each { |id| Spree::Collection.reset_counters(id, :product_collections) }
          Spree::Product.reset_counters(product.id, :product_collections)
        end

        success(product)
      end

      private

      def product_collection_attributes(collection, product, position)
        {
          collection_id: collection.id,
          product_id: product.id,
          position: position,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
    end
  end
end
