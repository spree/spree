class AddOrderIdToSpreeAdjustments < ActiveRecord::Migration
  def change
    add_column :spree_adjustments, :order_id, :integer
    add_index :spree_adjustments, :order_id
  end
end
