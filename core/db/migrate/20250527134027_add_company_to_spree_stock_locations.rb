class AddCompanyToSpreeStockLocations < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_stock_locations, :company, :string
  end
end
