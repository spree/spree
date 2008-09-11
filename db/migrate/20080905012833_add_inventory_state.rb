class AddInventoryState < ActiveRecord::Migration
  def self.up
    change_table :inventory_units do |t|
      t.rename :status, :state
    end
  end

  def self.down
    change_table :inventory_units do |t|
      t.rename :state, :status
    end
  end
end
