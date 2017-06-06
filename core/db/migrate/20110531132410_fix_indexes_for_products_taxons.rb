class FixIndexesForProductsTaxons < ActiveRecord::Migration
  def self.up
    remove_index :products_taxons, :product_id
    remove_index :products_taxons, :taxon_id
    change_column :products_taxons, :product_id, :integer, :null => false
    change_column :products_taxons, :taxon_id, :integer, :null => false
    add_index :products_taxons, [:product_id, :taxon_id], :unique => true
    add_index :products_taxons, [:taxon_id, :product_id], :unique => true
  end

  def self.down
    remove_index :products_taxons, [:product_id, :taxon_id]
    remove_index :products_taxons, [:taxon_id, :product_id]
    change_column :products_taxons, :product_id, :integer, :null => true
    change_column :products_taxons, :taxon_id, :integer, :null => true
    add_index :products_taxons, :product_id
    add_index :products_taxons, :taxon_id
  end
end
