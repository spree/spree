class RemovePresentationFromTaxonomy < ActiveRecord::Migration
  def self.up
    remove_column :taxonomies, :presentation
    remove_column :taxons, :presentation
  end

  def self.down
    add_column :taxonomies, :presentation, :string, :null => false
    add_column :taxons, :presentation, :string, :null => false
  end
end
