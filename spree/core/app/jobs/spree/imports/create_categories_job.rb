module Spree
  module Imports
    class CreateCategoriesJob < Spree::Imports::BaseJob
      # Concurrent imports can race on `with_matching_name(...).first || create!(...)`
      # for the same category name and hit the unique index; a retry then finds
      # the peer's committed row.
      retry_on ActiveRecord::RecordNotUnique, wait: :polynomially_longer, attempts: 5

      def perform(product_id, store_id, taxon_pretty_names)
        product = Spree::Product.find(product_id)
        store = Spree::Store.find(store_id)

        with_store_content_locale(store) do
          categories = taxon_pretty_names.filter_map { |taxon_pretty_name| find_or_create_category(store, taxon_pretty_name) }
          product.categories = categories
        end
      end

      private

      # Walks a "Men -> Clothing -> Shirts" path, creating each missing level as a
      # store-owned category. The first segment becomes a top-level category.
      #
      # Looks up through .for_store rather than store.categories: an installation
      # that has not yet run the upgrade task still has categories with a NULL
      # store_id that resolve their store through a taxonomy, and store.categories
      # cannot see them — so an import would build a parallel tree beside the one
      # the merchant already has.
      def find_or_create_category(store, taxon_pretty_name)
        category_names = taxon_pretty_name.strip.split('->').map(&:strip).map(&:presence).compact
        return if category_names.empty?

        category_names.inject(nil) do |parent, category_name|
          siblings = Spree::Category.for_store(store).where(parent: parent)

          siblings.with_matching_name(category_name).first ||
            find_by_permalink(siblings, parent, category_name) ||
            store.categories.create!(name: category_name, parent: parent)
        end
      end

      # Uniqueness is on the permalink, and distinct names can normalize to the
      # same slug ("Foo Bar" and "Foo-Bar" both become "foo-bar"). Matching on
      # name alone would miss that row and then fail creating a duplicate.
      def find_by_permalink(siblings, parent, category_name)
        slug = category_name.to_s.to_url
        return if slug.blank?

        permalink = parent.present? ? "#{parent.permalink}/#{slug}" : slug
        siblings.find_by(permalink: permalink)
      end
    end
  end
end
