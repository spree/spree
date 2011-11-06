class ShipAddressIdForCheckouts < ActiveRecord::Migration
  def change
    add_column :checkouts, :ship_address_id, :integer
  end
end
