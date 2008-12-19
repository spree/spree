class CreateIndexes < ActiveRecord::Migration
  def self.up
    remove_index :products, [:permalink, :available_on]
 
    add_index(:products, :name)
    add_index(:products, :deleted_at)
    add_index(:variants, :product_id)
    add_index(:option_values_variants, :variant_id)
    add_index(:products_taxons, :product_id)
    add_index(:products_taxons, :taxon_id)
  end

  def self.down
    add_index :products, [:permalink, :available_on]
 
    remove_index(:products, :name)
    remove_index(:products, :deleted_at)
    remove_index(:variants, :product_id)
    remove_index(:option_values_variants, :variant_id)
    remove_index(:products_taxons, :product_id)
    remove_index(:products_taxons, :taxon_id)
  end
end
