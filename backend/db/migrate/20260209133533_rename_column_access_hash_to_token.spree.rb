# This migration comes from spree (originally 20210921070812)
class RenameColumnAccessHashToToken < ActiveRecord::Migration[5.2]
  def change
    if table_exists?(:spree_wishlists)
      rename_column(:spree_wishlists, :access_hash, :token) if column_exists?(:spree_wishlists, :access_hash)
      add_reference(:spree_wishlists, :store, index: true) unless column_exists?(:spree_wishlists, :store_id)
    end
  end
end
