class IndexCompletedAtOnSpreeOrders < ActiveRecord::Migration[4.2]
  def change
    add_index :spree_orders, :completed_at
  end
end
