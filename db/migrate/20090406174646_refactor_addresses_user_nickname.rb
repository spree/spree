class RefactorAddressesUserNickname < ActiveRecord::Migration
  def self.up
    change_table :addresses do |t|
      t.integer :user_id
      t.string :nickname
      t.integer :active
    end
    Address.find_in_batches do |addresses|
      addresses.each do |address|
        creditcard = Creditcard.find_by_address_id(address.id)
        shipment = Shipment.find_by_address_id(address.id)
        next if !(creditcard || shipment)
        address.user_id = creditcard ? creditcard.order.user.id : shipment.order.user.id
        address.nickname = address.address1
        address.active = 1
        address.save
        #If there is another duplicate address, remove duplicate and update order to reference address correctly
      end
    end
  end

  def self.down
    remove_column :addresses, :user_id
    remove_column :addresses, :nickname
    remove_column :addresses, :active
  end
end
