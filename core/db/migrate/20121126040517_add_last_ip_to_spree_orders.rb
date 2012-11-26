class AddLastIpToSpreeOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :last_ip_address, :string
  end
end
