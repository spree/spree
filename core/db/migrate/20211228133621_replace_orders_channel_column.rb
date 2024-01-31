class ReplaceOrdersChannelColumn < ActiveRecord::Migration[5.2]
  def change
    add_reference :spree_orders, :channel, foreign_key: { to_table: :spree_store_channels }

    Spree::Order.where.not(channel: [nil, '']).find_each do |order|
      channel = Spree::StoreChannel.create(store: order.store, name: order.channel)
      order.update(channel_id: channel.id)
    end

    remove_column :spree_orders, :channel
  end
end
