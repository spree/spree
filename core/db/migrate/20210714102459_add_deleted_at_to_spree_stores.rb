class AddDeletedAtToSpreeStores < ActiveRecord::Migration[5.2]
  def change
    add_column :spree_stores, :deleted_at, :datetime unless column_exists?(:spree_stores, :deleted_at)
    add_index :spree_stores, :deleted_at unless index_exists?(:spree_stores, :deleted_at)
  end
end
