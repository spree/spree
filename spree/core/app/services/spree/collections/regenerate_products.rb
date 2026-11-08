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

        # Loaded rather than plucked: a row dropped below is gone by the time
        # its deleted event can be published, so it has to be held.
        previous_rows = collection.product_collections.order(position: :asc).to_a
        previous_products_ids = previous_rows.map(&:product_id)
        matching_ids = collection.products_matching_rules.ids
        matching = matching_ids.to_set

        retained_rows = previous_rows.select { |row| matching.include?(row.product_id) }
        removed_rows = previous_rows - retained_rows
        added_ids = matching_ids - previous_products_ids

        # Hard-delete (no callbacks). Class-level delete rather than the
        # association proxy, which under `dependent: :destroy_async` doesn't
        # reliably remove rows here.
        Spree::ProductCollection.where(id: removed_rows.map(&:id)).delete_all if removed_rows.any?

        # Close the gaps the removals left, keeping the survivors in the order
        # they were already in. One statement rather than one per row:
        # dropping an early member shifts every row behind it.
        moved = retained_rows.each_with_index.filter_map do |row, index|
          next if row.position == index + 1

          { id: row.id, collection_id: collection.id, product_id: row.product_id,
            position: index + 1, created_at: row.created_at, updated_at: Time.current }
        end

        Spree::ProductCollection.upsert_all(moved, unique_by: (:id unless Spree.mysql?)) if moved.any?

        if added_ids.any?
          records_to_insert = added_ids.map.with_index(retained_rows.size + 1) do |product_id, position|
            product_collection_attributes(product_id, collection, position)
          end

          Spree::ProductCollection.insert_all(records_to_insert)
        end

        # Expire cache + reindex the union of previous and new members, so products
        # dropped when the match set empties also refresh their stale collection_ids.
        products = Spree::Product.where(id: (previous_products_ids + matching_ids).uniq)
        products.touch_all
        products.each(&:enqueue_search_index)

        # counter caches — bulk insert/delete bypass the ProductCollection counter_cache callbacks
        Spree::Collection.reset_counters(collection.id, :product_collections)
        Spree::Product.reset_counters_in_bulk(previous_products_ids + matching_ids, :product_collections)

        publish_membership_events(collection, removed_rows, added_ids)

        success(collection)
      end

      private

      def publish_membership_events(collection, removed_rows, added_ids)
        removed_rows.each { |row| row.publish_event('product_collection.deleted') }
        return if added_ids.empty?

        Spree::ProductCollection.where(collection_id: collection.id, product_id: added_ids).
          find_each { |row| row.publish_event('product_collection.created') }
      end

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
