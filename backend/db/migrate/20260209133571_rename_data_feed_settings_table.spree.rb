# This migration comes from spree (originally 20230415155958)
class RenameDataFeedSettingsTable < ActiveRecord::Migration[6.1]
  def change
    rename_table :spree_data_feed_settings, :spree_data_feeds
  end
end
