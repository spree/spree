class StateForShipments < ActiveRecord::Migration
  def self.up
    add_column "shipments", "state", :string
  end

  def self.down
    remove_column "shipments", "state"
  end
end
