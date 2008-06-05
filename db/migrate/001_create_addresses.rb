class CreateAddresses < ActiveRecord::Migration
  def self.up
	  create_table :addresses do |t|
      t.string  :firstname
      t.string  :lastname
      t.string  :address1
      t.string  :address2
      t.string  :city
      t.references :state
      t.string  :zipcode
      t.references :country
      t.string  :phone
      t.timestamps
	  end
  end

  def self.down
    drop_table :addresses
  end
end
