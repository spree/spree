class ShipmentIdForInventoryUnits < ActiveRecord::Migration
  def self.up
    add_column :inventory_units, :shipment_id, :integer
    add_index :inventory_units, :shipment_id

    # migrate legacy shipments
    Spree::Shipment.table_name = 'shipments'

    Spree::Shipment.all.each do |shipment|
      unless shipment.order
        puts "Warning: shipment has invalid order - #{shipment.id}"
        next
      end
      shipment.order.inventory_units.each do |unit|
        unit.update_attribute('shipment_id', shipment.id)
      end
    end

    Spree::Shipment.table_name = 'spree_shipments'
  end

  def self.down
    remove_column :inventory_units, :shipment_id
  end
end
