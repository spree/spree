class AddTokenToSpreeOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :guest_token, :string
  end
end
