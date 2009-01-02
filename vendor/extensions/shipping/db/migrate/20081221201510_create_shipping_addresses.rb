class CreateShippingAddresses < ActiveRecord::Migration
  def self.up
    # migrate legacy addresses that are associated directly with the orders
    Address.find(:all, :conditions => ["addressable_type = 'Order'"]).each do |address|
      order = Order.find address.addressable_id  
      shipment = order.shipments.first
      # due to an existing bug its possible some orders may have no shipment
      next if shipment.nil?
      shipment.address = address
      shipment.save
    end
  end

  def self.down
  end
end