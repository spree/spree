class AddDescriptionToTaxons < ActiveRecord::Migration
  def self.up
    # skip this migration if the attribute already exists because of advanced taxon extension
    add_column :taxons, :description, :text unless column_exists?(:taxons, :description)
  end

  def self.down
    remove_column :taxons, :description
  end
end
