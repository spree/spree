# This migration comes from spree (originally 20210920090344)
class AddDeletedAtToSpreeStores < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:spree_stores, :deleted_at)
      add_column :spree_stores, :deleted_at, :datetime
      add_index :spree_stores, :deleted_at
    end
  end
end
