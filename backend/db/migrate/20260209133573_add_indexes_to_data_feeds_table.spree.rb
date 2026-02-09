# This migration comes from spree (originally 20230415161226)
class AddIndexesToDataFeedsTable < ActiveRecord::Migration[6.1]
  def change
    add_index :spree_data_feeds, [:store_id, :slug, :provider]
  end
end
