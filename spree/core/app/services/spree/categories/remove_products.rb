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
          Spree::ProductCategory.where(category_id: category_ids, product_id: product_ids).delete_all

          # What survived the delete, for every category at once: re-packing
          # positions category by category is a read per category on a bulk
          # removal.
          remaining_by_category = Hash.new { |hash, key| hash[key] = [] }
          Spree::ProductCategory.
            where(category_id: category_ids).
            order(:position).
            pluck(:category_id, :product_id).
            each { |category_id, product_id| remaining_by_category[category_id] << product_id }

          product_categories_params = category_ids.flat_map do |category_id|
            position = 0

            remaining_by_category[category_id].map do |product_id|
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
        Spree::Product.reset_categories_counts(product_ids)
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
        Spree.mysql?
      end
    end
  end
end
