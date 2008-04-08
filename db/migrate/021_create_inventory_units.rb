class CreateInventoryUnits < ActiveRecord::Migration
  def self.up
    create_table :inventory_units do |t|
      t.integer :variant_id
      t.integer :order_id
      t.integer :status
      t.integer :lock_version, :default => 0
      t.timestamps
    end
  end

  def self.down
    drop_table :inventory_units
  end
end