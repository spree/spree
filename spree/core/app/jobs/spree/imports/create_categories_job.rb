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
      def find_or_create_category(store, taxon_pretty_name)
        category_names = taxon_pretty_name.strip.split('->').map(&:strip).map(&:presence).compact
        return if category_names.empty?

        category_names.inject(nil) do |parent, category_name|
          store.categories.where(parent: parent).with_matching_name(category_name).first ||
            store.categories.create!(name: category_name, parent: parent)
        end
      end
    end
  end
end
