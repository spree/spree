class CreateAddressKeysForOrder < ActiveRecord::Migration
  def change
    add_column :orders, :bill_address_id, :integer
    add_column :orders, :ship_address_id, :integer
  end
end