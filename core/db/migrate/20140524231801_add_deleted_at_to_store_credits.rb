class AddDeletedAtToStoreCredits < ActiveRecord::Migration
  def change
    add_column :spree_store_credits, :deleted_at, :datetime
    add_index :spree_store_credits, :deleted_at
  end
end
