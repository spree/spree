class CreateIndexesForInventoryUnits < ActiveRecord::Migration
  def self.up
    add_index(:inventory_units, :variant_id)
    add_index(:inventory_units, :order_id)
  end

  def self.down
    remove_index(:inventory_units, :variant_id)
    remove_index(:inventory_units, :order_id)
  end
end

