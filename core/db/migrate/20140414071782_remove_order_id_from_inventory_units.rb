class RemoveOrderIdFromInventoryUnits < ActiveRecord::Migration
  def up
    remove_column :spree_inventory_units, :order_id
  end
end
