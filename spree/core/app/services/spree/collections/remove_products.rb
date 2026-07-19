module Spree
  module Collections
    class RemoveProducts
      prepend Spree::ServiceModule::Base

      # Removes the given products from the given collections and re-packs positions.
      #
      # @param collections [Array<Spree::Collection>]
      # @param products [Array<Spree::Product>]
      # @return [Spree::ServiceModule::Base::Result]
      def call(collections:, products:)
        return if collections.blank? || products.blank?

        collection_ids = collections.pluck(:id)
        product_ids = products.pluck(:id)

        ApplicationRecord.transaction do
          collection_ids.each do |collection_id|
            Spree::ProductCollection.where(collection_id: collection_id, product_id: product_ids).delete_all
          end

          product_collections_params = collection_ids.flat_map do |collection_id|
            position = 0
            existing_product_ids = Spree::ProductCollection.where(collection_id: collection_id).pluck(:product_id)

            existing_product_ids.map do |product_id|
              {
                collection_id: collection_id,
                product_id: product_id,
                position: (position += 1),
                created_at: Time.current,
                updated_at: Time.current
              }
            end
          end

          if product_collections_params.any?
            opts = {}
            # Column list rather than the index name — the composite unique index is named
            # index_product_collections_on_collection_and_product (shortened to fit the
            # identifier limit), so match by columns to stay name-independent.
            opts[:unique_by] = %i[collection_id product_id] unless mysql_adapter?

            Spree::ProductCollection.upsert_all(product_collections_params, **opts)
          end
        end

        collection_ids.each { |id| Spree::Collection.reset_counters(id, :product_collections) }
        product_ids.each { |id| Spree::Product.reset_counters(id, :product_collections) }

        Spree::Product.where(id: product_ids).touch_all
        products.each(&:enqueue_search_index)
        Spree::Collection.where(id: collection_ids).touch_all

        success(true)
      end

      private

      def mysql_adapter?
        ActiveRecord::Base.connection.adapter_name.downcase.include?('mysql')
      end
    end
  end
end
