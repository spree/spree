class AddStateLockVersionToOrder < ActiveRecord::Migration
  def change
    add_column :spree_orders, :state_lock_version, :integer, default: 0, null: false
  end
end
