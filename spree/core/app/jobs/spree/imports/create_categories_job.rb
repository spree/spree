module Spree
  module Imports
    class CreateCategoriesJob < Spree::Imports::BaseJob
      # Concurrent imports can race on `with_matching_name(...).first || create!(...)`
      # for the same taxonomy/taxon name and hit the unique index; a retry then finds
      # the peer's committed row.
      retry_on ActiveRecord::RecordNotUnique, wait: :polynomially_longer, attempts: 5

      def perform(product_id, store_id, taxon_pretty_names)
        product = Spree::Product.find(product_id)
        store = Spree::Store.find(store_id)

        with_store_content_locale(store) do
          taxons = taxon_pretty_names.filter_map { |taxon_pretty_name| find_or_create_taxon(store, taxon_pretty_name) }
          product.taxons = taxons
        end
      end

      private

      def find_or_create_taxon(store, taxon_pretty_name)
        taxon_names = taxon_pretty_name.strip.split('->').map(&:strip).map(&:presence).compact
        return if taxon_names.empty?

        taxonomy_name = taxon_names.shift
        taxonomy = store.taxonomies.with_matching_name(taxonomy_name).first || store.taxonomies.create!(name: taxonomy_name)

        last_taxon = taxonomy.root

        taxon_names.each do |taxon_name|
          last_taxon = taxonomy.taxons.with_matching_name(taxon_name).where(parent: last_taxon).first ||
                       taxonomy.taxons.create!(name: taxon_name, parent: last_taxon)
        end

        last_taxon
      end
    end
  end
end
