module Spree
  module Categories
    class AddProducts
      prepend Spree::ServiceModule::Base
      include Spree::ProductMemberships

      # Adds the given products to the given categories, in bulk.
      #
      # @param categories [Array<Spree::Category>]
      # @param products [Array<Spree::Product>]
      # @return [Spree::ServiceModule::Base::Result]
      def call(categories:, products:)
        return if categories.blank? || products.blank?

        add_memberships(categories, products)
        success(true)
      end

      private

      def membership_class = Spree::ProductCategory
      def group_class = Spree::Category

      # Recomputes the descendant-inclusive products_count for the categories
      # and their ancestors, and lets an optional storefront extension refresh
      # its featured sections.
      def refresh_group_counters(category_ids)
        Spree::Category.recalculate_products_count(category_ids)
        Spree::Taxons::TouchFeaturedSections.call(taxon_ids: category_ids) if defined?(Spree::Taxons::TouchFeaturedSections)
      end
    end
  end
end
