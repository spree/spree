class AddIconToTaxons < ActiveRecord::Migration
    def up
      # legacy table support
      Spree::Taxon.table_name = 'taxons'
      # skip this migration if the attribute already exists because of advanced taxon extension
      return if Spree::Taxon.new.respond_to? :icon_file_name
      add_column :taxons, :icon_file_name,    :string
      add_column :taxons, :icon_content_type, :string
      add_column :taxons, :icon_file_size,    :integer
      add_column :taxons, :icon_updated_at,   :datetime

      Spree::Taxon.table_name = 'spree_taxons'
    end

    def down
      remove_column :taxons, :icon_file_name
      remove_column :taxons, :icon_content_type
      remove_column :taxons, :icon_file_size
      remove_column :taxons, :icon_updated_at
    end

end
