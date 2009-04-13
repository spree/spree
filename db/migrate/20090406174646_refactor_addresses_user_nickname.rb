class RefactorAddressesUserNickname < ActiveRecord::Migration
  def self.up
    change_table :addresses do |t|
      t.integer :user_id
      t.string :nickname
    end
    Address.find_in_batches do |addresses|
      addresses.each do |address|
        creditcard = Creditcard.find_by_address_id(address.id)
        shipment = Shipment.find_by_address_id(address.id)
        address.user_id = creditcard ? creditcard.user.id : shipment.user.id
        address.save
      end
    end
  end

  def self.down
  end
end
