class AddLineItemIdToSpreeInventoryUnits < ActiveRecord::Migration
  def change
    # Stores running the product-assembly extension already have a line_item_id column
    unless column_exists? Spree::InventoryUnit.table_name, :line_item_id
      add_column :spree_inventory_units, :line_item_id, :integer
      add_index :spree_inventory_units, :line_item_id

      Spree::InventoryUnit.update_all("line_item_id = variant_id")
    end
  end
end
