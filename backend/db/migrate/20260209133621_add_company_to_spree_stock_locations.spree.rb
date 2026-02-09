# This migration comes from spree (originally 20250527134027)
class AddCompanyToSpreeStockLocations < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_stock_locations, :company, :string, if_not_exists: true
  end
end
