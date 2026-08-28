class CreateSpreeChannelMarkets < ActiveRecord::Migration[8.1]
  # Optional Channel → Market allowlist (docs/plans/6.0-channel-markets.md):
  # no rows means the channel serves every market of its store, so existing
  # stores upgrade with zero behavior change.
  #
  # `default_market_id` overrides which of the served markets a visitor lands
  # in when their country resolves to none. Null derives it — the store
  # default when the channel serves it, else the first allowed by position.
  def change
    create_table :spree_channel_markets do |t|
      t.references :channel, null: false
      t.references :market, null: false
      t.timestamps
    end

    add_index :spree_channel_markets, [:channel_id, :market_id],
              unique: true, name: 'idx_channel_markets_uniqueness'

    add_reference :spree_channels, :default_market
  end
end
