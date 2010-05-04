class AddAddressesCheckoutsIndexes < ActiveRecord::Migration
  def self.up
    add_index :addresses, :firstname
    add_index :addresses, :lastname
    add_index :checkouts, :order_id
    add_index :checkouts, :bill_address_id
  end

  def self.down
    remove_index :checkouts, :bill_address_id
    remove_index :checkouts, :order_id
    remove_index :addresses, :lastname
    remove_index :addresses, :firstname
  end
end

