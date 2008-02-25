class CreateAddresses < ActiveRecord::Migration
  def self.up
	  create_table :addresses do |t|
      t.string  :firstname
      t.string  :lastname
      t.string  :address1
      t.string  :address2
      t.string  :city
      t.integer :state_id
      t.string  :zipcode
      t.integer :country_id
      t.string  :phone
      t.timestamps
	  end
  end

  def self.down
    drop_table :addresses
  end
end