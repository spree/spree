class AddUserIdIndexToSpreeOrders < ActiveRecord::Migration
  def change
    add_index :spree_orders, :user_id
  end
end
