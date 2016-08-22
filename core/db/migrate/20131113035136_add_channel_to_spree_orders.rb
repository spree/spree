class AddChannelToSpreeOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_orders, :channel, :string, default: "spree"
  end
end
