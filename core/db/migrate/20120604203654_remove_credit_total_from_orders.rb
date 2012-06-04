class RemoveCreditTotalFromOrders < ActiveRecord::Migration
  def change
    remove_column :spree_orders, :credit_total
  end
end
