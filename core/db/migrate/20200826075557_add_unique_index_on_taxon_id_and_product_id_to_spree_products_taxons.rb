class AddUniqueIndexOnTaxonIdAndProductIdToSpreeProductsTaxons < ActiveRecord::Migration[6.0]
  def change
    add_index :spree_products_taxons, [:product_id, :taxon_id], unique: true unless index_exists? :spree_products_taxons, [:product_id, :taxon_id]
  end
end
