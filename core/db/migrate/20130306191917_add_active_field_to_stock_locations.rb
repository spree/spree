class AddActiveFieldToStockLocations < ActiveRecord::Migration
  def change
    add_column :spree_stock_locations, :active, :boolean, :default => true
  end
end
