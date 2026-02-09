# This migration comes from spree (originally 20240623172111)
class AddDeletedAtToSpreeStockLocations < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_stock_locations, :deleted_at, :datetime, if_not_exists: true
    add_index :spree_stock_locations, :deleted_at, if_not_exists: true
  end
end
