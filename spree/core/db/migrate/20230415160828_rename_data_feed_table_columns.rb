class RenameDataFeedTableColumns < ActiveRecord::Migration[6.1]
  def change
    rename_column :spree_data_feeds, :spree_store_id, :store_id
    rename_column :spree_data_feeds, :enabled, :active
    rename_column :spree_data_feeds, :uuid, :slug
  end
end
