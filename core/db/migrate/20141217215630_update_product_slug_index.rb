class UpdateProductSlugIndex < ActiveRecord::Migration
  def change
    remove_index :spree_products, :slug if index_exists?(:spree_products, :slug)
    add_index :spree_products, :slug, unique: true
  end
end
