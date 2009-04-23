class RefactorAddresses < ActiveRecord::Migration
  def self.up  
    change_table :orders do |t|
      t.integer :bill_address_id
      t.integer :ship_address_id
    end                              
    change_table :shipments do |t|
      t.references :address
    end
    change_table :creditcards do |t|
      t.references :address
    end    

    Order.reset_column_information
    Shipment.reset_column_information
    Creditcard.reset_column_information
    
    Address.find_in_batches do |addresses|
      addresses.each do |address|
        if address.addressable_type == "Creditcard"
          creditcard = Creditcard.find address.addressable_id
          creditcard.address = address
          creditcard.save
          order = creditcard.order

          if order
            order.bill_address = address
            order.save
		      end

        elsif address.addressable_type == "Shipment"
          shipment = Shipment.find address.addressable_id 
          shipment.address = address
          shipment.save
          order = shipment.order
          if order
            order.ship_address = address
            order.save
          end
        end
      end
    end

    change_table :addresses do |t|
      t.remove :addressable_id
      t.remove :addressable_type
    end    

  end

  def self.down
  end
end
