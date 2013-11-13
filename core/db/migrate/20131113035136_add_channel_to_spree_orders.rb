class AddChannelToSpreeOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :channel, :string, default: "spree"
  end
end
