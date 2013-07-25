class AddCreatedByIdToSpreeOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :created_by_id, :integer
  end
end
