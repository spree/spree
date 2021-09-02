class RenameColumnAccessHashToToken < ActiveRecord::Migration[5.2]
  def change
    if table_exists?(:spree_wishlists)
      rename_column(:spree_wishlists, :access_hash, :token) if column_exists?(:spree_wishlists, :access_hash)
    end
  end
end
