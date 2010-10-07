class AddIconToTaxons < ActiveRecord::Migration
    def self.up
      # skip this migration if the attribute already exists because of advanced taxon extension
      return if Taxon.new.respond_to? :icon_file_name
      add_column :taxons, :icon_file_name,    :string
      add_column :taxons, :icon_content_type, :string
      add_column :taxons, :icon_file_size,    :integer
      add_column :taxons, :icon_updated_at,   :datetime
    end

    def self.down
      remove_column :taxons, :icon_file_name
      remove_column :taxons, :icon_content_type
      remove_column :taxons, :icon_file_size
      remove_column :taxons, :icon_updated_at
    end

end
