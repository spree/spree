class RemoveExtraProductsSlugIndex < ActiveRecord::Migration
  def change
    remove_index :spree_products, name: :permalink_idx_unique
  end
end
