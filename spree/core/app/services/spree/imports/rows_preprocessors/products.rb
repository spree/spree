module Spree
  module Imports
    module RowsPreprocessors
      class Products
        def initialize(import)
          @import = import
        end

        attr_reader :import
        delegate :mappings, :rows, :store, to: :import

        def preprocess_rows!
          ensure_taxonomies_and_taxons!
        end

        private

        def ensure_taxonomies_and_taxons!
          category_mappings = mappings.mapped.where(schema_field: %w[category1 category2 category3])
          return if category_mappings.empty?

          file_columns = category_mappings.pluck(:file_column)
          taxon_pretty_names = Set.new

          rows.find_each do |row|
            file_columns.each do |category_column|
              taxon_pretty_name = row.data_json[category_column].to_s.strip.presence
              taxon_pretty_names << taxon_pretty_name if taxon_pretty_name
            end
          end
          return if taxon_pretty_names.empty?

          taxon_pretty_names.each do |taxon_pretty_name|
            taxon_names = taxon_pretty_name.split('->').map(&:strip).map(&:presence).compact
            next if taxon_names.empty?

            taxonomy_name = taxon_names.shift
            taxonomy = store.taxonomies.with_matching_name(taxonomy_name).first || store.taxonomies.create!(name: taxonomy_name)
            last_taxon = taxonomy.root

            taxon_names.each do |taxon_name|
              last_taxon = taxonomy.taxons.with_matching_name(taxon_name).where(parent: last_taxon).first || taxonomy.taxons.create!(name: taxon_name, parent: last_taxon)
            end
          end
        end
      end
    end
  end
end
