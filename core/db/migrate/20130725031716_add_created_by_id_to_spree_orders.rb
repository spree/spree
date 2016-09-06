class AddCreatedByIdToSpreeOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_orders, :created_by_id, :integer
  end
end
