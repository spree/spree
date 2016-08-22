class AddLastIpToSpreeOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_orders, :last_ip_address, :string
  end
end
