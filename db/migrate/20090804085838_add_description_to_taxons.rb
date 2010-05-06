class AddDescriptionToTaxons < ActiveRecord::Migration
    def self.up
      add_column :taxons, :description, :text
    end

    def self.down
      remove_column :taxons, :description
    end
end
