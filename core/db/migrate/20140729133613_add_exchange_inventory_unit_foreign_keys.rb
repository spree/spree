class AddExchangeInventoryUnitForeignKeys < ActiveRecord::Migration
  def change
    add_column :spree_return_items, :exchange_inventory_unit_id, :integer

    add_index :spree_return_items, :exchange_inventory_unit_id
  end
end
