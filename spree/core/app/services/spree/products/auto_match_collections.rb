module Spree
  module Products
    class AutoMatchCollections
      prepend ::Spree::ServiceModule::Base

      # Re-evaluates a product against the rules of its store's collections:
      # rule rows it no longer matches are removed and collections it now
      # matches gain a rule row at the end. Hand-picked rows and exclusions
      # are left as they are.
      #
      # @param product [Spree::Product]
      # @return [Spree::ServiceModule::Base::Result]
      def call(product:)
        return unless product.present?

        collections = Spree::Collection.automatic.where(store_id: product.store_id).includes(:rules, :store).to_a
        memberships = Spree::ProductCollection.where(product_id: product.id, collection_id: collections.map(&:id)).index_by(&:collection_id)
        excluded_ids = Spree::CollectionExclusion.where(product_id: product.id, collection_id: collections.map(&:id)).pluck(:collection_id)

        to_remove = []
        to_add = []

        collections.each do |collection|
          membership = memberships[collection.id]
          next if membership&.source == 'manual' || excluded_ids.include?(collection.id)

          matches = collection.products_matching_rules(product_ids: [product.id]).exists?
          to_remove << collection if membership && !matches
          to_add << collection if membership.nil? && matches
        end

        # A row from before 6.1 has no source; on an automatic collection its rules made it.
        Spree::ProductCollection.where(product_id: product.id, collection_id: to_remove.map(&:id), source: [nil, 'rule']).delete_all if to_remove.any?
        add(product, to_add)

        affected_ids = (to_remove + to_add).map(&:id)
        refresh(product, affected_ids) if affected_ids.any?

        success(product)
      end

      private

      def add(product, collections)
        return if collections.empty?

        last_positions = Spree::ProductCollection.where(collection_id: collections.map(&:id)).group(:collection_id).maximum(:position)
        now = Time.current

        Spree::ProductCollection.insert_all(
          collections.map do |collection|
            {
              collection_id: collection.id, product_id: product.id, source: 'rule',
              position: last_positions[collection.id].to_i + 1, created_at: now, updated_at: now
            }
          end
        )
      end

      # Bulk writes skip the counter caches and touches, so they happen here.
      def refresh(product, collection_ids)
        Spree::Collection.where(id: collection_ids).touch_all
        Spree::Collection.reset_counters_in_bulk(collection_ids, :product_collections)
        Spree::Product.reset_counters(product.id, :product_collections)
        product.touch
        product.enqueue_search_index
      end
    end
  end
end
