class AddPickupToSpreeStockLocations < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_stock_locations, :kind, :string, null: false, default: 'warehouse', if_not_exists: true
    add_column :spree_stock_locations, :pickup_enabled, :boolean, null: false, default: false, if_not_exists: true
    add_column :spree_stock_locations, :pickup_stock_policy, :string, null: false, default: 'local', if_not_exists: true
    add_column :spree_stock_locations, :pickup_ready_in_minutes, :integer, if_not_exists: true
    add_column :spree_stock_locations, :pickup_instructions, :text, if_not_exists: true

    add_index :spree_stock_locations, :pickup_enabled, if_not_exists: true
    add_index :spree_stock_locations, :kind, if_not_exists: true
  end
end
