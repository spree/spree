class AddApproverIdAndApprovedAtToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_orders, :approver_id, :integer
    add_column :spree_orders, :approved_at, :datetime
  end
end
