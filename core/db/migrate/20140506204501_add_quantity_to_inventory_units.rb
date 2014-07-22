class AddQuantityToInventoryUnits < ActiveRecord::Migration
  def change
    add_column :spree_inventory_units, :quantity, :integer
    execute "UPDATE spree_inventory_units SET quantity = 1"
  end
end
