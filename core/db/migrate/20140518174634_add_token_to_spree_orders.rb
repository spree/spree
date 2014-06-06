class AddTokenToSpreeOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :token, :string
  end
end
