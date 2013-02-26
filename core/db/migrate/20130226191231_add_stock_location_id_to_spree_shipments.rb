class AddStockLocationIdToSpreeShipments < ActiveRecord::Migration
  def change
    add_column :spree_shipments, :stock_location_id, :integer
  end
end
