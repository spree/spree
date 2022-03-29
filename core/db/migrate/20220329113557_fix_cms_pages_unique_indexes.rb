class FixCmsPagesUniqueIndexes < ActiveRecord::Migration[5.2]
  def change
    remove_index :spree_cms_pages, [:slug, :store_id, :deleted_at]
    remove_index :spree_cms_pages, [:slug, :store_id], unique: true

    add_index :spree_cms_pages, [:slug, :store_id, :deleted_at], unique: true
  end
end
