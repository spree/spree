class AddIndexesToDataFeedsTable < ActiveRecord::Migration[6.1]
  def change
    add_index :spree_data_feeds, [:store_id, :slug, :provider]
  end
end
