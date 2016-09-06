class AddDefaultToSpreeStockLocations < ActiveRecord::Migration[4.2]
  def change
    unless column_exists? :spree_stock_locations, :default
      add_column :spree_stock_locations, :default, :boolean, null: false, default: false
    end
  end
end
