class AddDefaultAddressesToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :ship_address_id, :integer
    add_column :users, :bill_address_id, :integer
  end

  def self.down
    remove_column :users, :bill_address_id
    remove_column :users, :ship_address_id
  end
end
