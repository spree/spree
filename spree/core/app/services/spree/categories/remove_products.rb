module Spree
  module Categories
    class RemoveProducts
      prepend Spree::ServiceModule::Base

      # Removes the given products from the given categories.
      #
      # @param categories [Array<Spree::Category>]
      # @param products [Array<Spree::Product>]
      # @return [Spree::ServiceModule::Base::Result]
      def call(categories:, products:)
        return if categories.blank? || products.blank?

        category_ids = categories.pluck(:id)
        product_ids = products.pluck(:id)

        ApplicationRecord.transaction do
          category_ids.each do |category_id|
            Spree::ProductCategory.where(category_id: category_id, product_id: product_ids).delete_all
          end

          product_categories_params = category_ids.flat_map do |category_id|
            position = 0
            existing_product_ids = Spree::ProductCategory.where(category_id: category_id).pluck(:product_id)

            existing_product_ids.map do |product_id|
              {
                category_id: category_id,
                product_id: product_id,
                position: (position += 1),
                created_at: Time.current,
                updated_at: Time.current
              }
            end
          end

          if product_categories_params.any?
            opts = {}
            opts[:unique_by] = %i[product_id category_id] unless mysql_adapter?

            Spree::ProductCategory.upsert_all(
              product_categories_params,
              **opts
            )
          end
        end

        # update counter caches
        product_ids.each { |id| Spree::Product.reset_counters(id, :product_categories) }
        # Recompute the descendant-inclusive products_count for the categories and
        # their ancestors (delete_all skips ProductCategory callbacks).
        Spree::Category.recalculate_products_count(category_ids)

        # clear cache & index products
        Spree::Product.where(id: product_ids).touch_all
        products.each(&:enqueue_search_index)

        Spree::Category.where(id: category_ids).touch_all
        # Optional external hook (e.g. storefront featured sections); namespace owned by that gem.
        Spree::Taxons::TouchFeaturedSections.call(taxon_ids: category_ids) if defined?(Spree::Taxons::TouchFeaturedSections)

        success(true)
      end

      private

      def mysql_adapter?
        ActiveRecord::Base.connection.adapter_name.downcase.include?('mysql')
      end
    end
  end
end
