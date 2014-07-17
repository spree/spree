class AddDefaultToSpreeStockLocations < ActiveRecord::Migration
  def change
    add_column :spree_stock_locations, :default, :boolean, null: false, default: false
  end
end
