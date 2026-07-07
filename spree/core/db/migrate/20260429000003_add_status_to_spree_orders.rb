class AddStatusToSpreeOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_orders, :status, :string, if_not_exists: true
    add_index :spree_orders, :status, if_not_exists: true
  end
end
