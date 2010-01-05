class ShipmentIdForInventoryUnits < ActiveRecord::Migration
  def self.up
    add_column "inventory_units", "shipment_id", :integer
  end

  def self.down
    remove_column "inventory_units", "shipment_id"
  end
end
