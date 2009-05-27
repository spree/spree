class RemoveAddressOrphans < ActiveRecord::Migration
  def self.up
    a_orphans = Address.all.reject do |a| 
                  Order.find_by_ship_address_id(a.id) or 
                  Order.find_by_bill_address_id(a.id) or 
                  Creditcard.find_by_address_id(a.id) or 
                  Shipment.find_by_address_id(a.id)
                end
    a_orphans.each {|a| a.destroy}
  end

  def self.down
    # nothing needed
  end
end
