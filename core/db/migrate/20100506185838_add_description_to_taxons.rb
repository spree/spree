class AddDescriptionToTaxons < ActiveRecord::Migration
    def self.up
      # skip this migration if the attribute already exists because of advanced taxon extension
      return if column_exists?(:taxons, :description)
      add_column :taxons, :description, :text
    end

    def self.down
      remove_column :taxons, :description
    end
end
