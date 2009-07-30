class RemoveCheckoutShippingAddressAndMethod < ActiveRecord::Migration
  def self.up      
    change_table :checkouts do |t|
      t.remove :ship_address_id
      t.remove :shipping_method_id
    end
  end

  def self.down                   
    change_table :checkouts do |t|
      t.references :shipping_method
      t.integer :ship_address_id
    end
  end
end
