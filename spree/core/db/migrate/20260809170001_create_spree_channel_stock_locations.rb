class CreateSpreeChannelStockLocations < ActiveRecord::Migration[8.1]
  # Optional Channel → StockLocation allowlist
  # (docs/plans/6.0-channel-delivery.md): no rows means the channel is served
  # by every store location, so existing stores upgrade with zero behavior
  # change.
  def change
    create_table :spree_channel_stock_locations do |t|
      t.references :channel, null: false
      t.references :stock_location, null: false
      t.timestamps
    end

    add_index :spree_channel_stock_locations,
              [:channel_id, :stock_location_id],
              unique: true, name: 'idx_channel_stock_locations_uniqueness'
  end
end
