class ShipAddressIdForCheckouts < ActiveRecord::Migration
  def self.up
    add_column "checkouts", "ship_address_id", :integer
  end

  def self.down
    remove_column "checkouts", "ship_address_id"
  end
end
