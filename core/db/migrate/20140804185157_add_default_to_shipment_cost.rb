class AddDefaultToShipmentCost < ActiveRecord::Migration
  def up
    change_column :spree_shipments, :cost, :decimal, precision: 10, scale: 2, default: 0.0
    Spree::Shipment.where(cost: nil).update_all(cost: 0)
  end

  def down
    change_column :spree_shipments, :cost, :decimal, precision: 10, scale: 2
  end
end
