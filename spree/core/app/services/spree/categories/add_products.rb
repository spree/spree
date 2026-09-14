module Spree
  module Categories
    class AddProducts
      prepend Spree::ServiceModule::Base

      # Creates product-category links for the given categories and products in bulk.
      #
      # @param categories [Array<Spree::Category>]
      # @param products [Array<Spree::Product>]
      # @return [Spree::ServiceModule::Base::Result]
      def call(categories:, products:)
        return if categories.blank? || products.blank?

        category_ids = categories.pluck(:id)
        # Every category's current size in one grouped count: a bulk assign
        # across many categories would otherwise probe each one for the
        # position to append at.
        positions = Spree::ProductCategory.where(category_id: category_ids).group(:category_id).count

        # build the params for the insert_all
        product_categories_params = category_ids.flat_map do |category_id|
          position = positions.fetch(category_id, 0)

          products.pluck(:id).map do |product_id|
            {
              category_id: category_id,
              product_id: product_id,
              position: (position += 1),
              created_at: Time.current,
              updated_at: Time.current
            }
          end
        end
        # doing a quick insert_all here to avoid the overhead of instantiating
        Spree::ProductCategory.insert_all(product_categories_params)

        # update counter caches
        product_ids = products.pluck(:id)
        Spree::Product.reset_categories_counts(product_ids)
        # Recompute the descendant-inclusive products_count for the categories and
        # their ancestors (bulk insert skips ProductCategory callbacks).
        Spree::Category.recalculate_products_count(category_ids)

        # clear cache & index products
        Spree::Product.where(id: product_ids).touch_all
        products.each(&:enqueue_search_index)

        Spree::Category.where(id: category_ids).touch_all
        # Optional external hook (e.g. storefront featured sections); namespace owned by that gem.
        Spree::Taxons::TouchFeaturedSections.call(taxon_ids: category_ids) if defined?(Spree::Taxons::TouchFeaturedSections)

        success(true)
      end
    end
  end
end
