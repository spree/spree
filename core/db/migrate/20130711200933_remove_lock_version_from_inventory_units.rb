class RemoveLockVersionFromInventoryUnits < ActiveRecord::Migration
  def change
    # we are moving to pessimistic locking on stock_items
    remove_column :spree_inventory_units, :lock_version
  end
end
