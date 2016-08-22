class AddUserIdIndexToSpreeOrders < ActiveRecord::Migration[4.2]
  def change
    add_index :spree_orders, :user_id
  end
end
