class AddAdminNameColumnToSpreeStockLocations < ActiveRecord::Migration
  def change
    add_column :spree_stock_locations, :admin_name, :string
  end
end
