class AddCancelAuditFieldsToSpreeOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_orders, :canceled_at, :datetime
    add_column :spree_orders, :canceler_id, :integer
  end
end
