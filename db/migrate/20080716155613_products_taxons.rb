class ProductsTaxons < ActiveRecord::Migration
  def self.up
    create_table :products_taxons, :id => false do |t|
      t.integer :product_id
      t.integer :taxon_id
    end
  end

  def self.down
    drop_table :products_taxons
  end
end
