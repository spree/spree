class UpdateProductSlugIndex < ActiveRecord::Migration[4.2]
  def change
    remove_index :spree_products, :slug if index_exists?(:spree_products, :slug)
    add_index :spree_products, :slug, unique: true
  end
end
