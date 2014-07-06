class AddLineItemIdToSpreeInventoryUnits < ActiveRecord::Migration
  def change
    # Stores running the product-assembly extension already have a line_item_id column
    unless column_exists? Spree::InventoryUnit.table_name, :line_item_id
      add_column :spree_inventory_units, :line_item_id, :integer
      add_index :spree_inventory_units, :line_item_id

      shipments = Spree::Shipment.includes(:inventory_units, :order)

      shipments.find_each do |shipment|
        shipment.inventory_units.group_by(&:variant_id).each do |variant_id, units|

          line_item = shipment.order.line_items.find_by(variant_id: variant_id)
          next unless line_item

          Spree::InventoryUnit.where(id: units.map(&:id)).update_all(line_item_id: line_item.id)
        end
      end
    end
  end
end
