class CreateAddressKeysForOrder < ActiveRecord::Migration
  def self.up
    change_table :orders do |t|
      t.integer :bill_address_id
      t.integer :ship_address_id
    end
  end

  def self.down
    change_table :orders do |t|
      t.remove :bill_address_id
      t.remove :ship_address_id
    end
  end
end
