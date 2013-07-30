class IndexCompletedAtOnSpreeOrders < ActiveRecord::Migration
  def change
    add_index :spree_orders, :completed_at
  end
end
