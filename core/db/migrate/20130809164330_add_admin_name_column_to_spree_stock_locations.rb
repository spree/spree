class AddAdminNameColumnToSpreeStockLocations < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_stock_locations, :admin_name, :string
  end
end
