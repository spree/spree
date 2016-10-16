class AddStockLocationIdToSpreeShipments < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_shipments, :stock_location_id, :integer
  end
end
