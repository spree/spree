class CreateShippingAddresses < ActiveRecord::Migration
  def self.up
    # migrate legacy addresses that are associated directly with the orders
    Order.all.each do |order|
      Address.find(:all, :conditions => ["addressable_type = 'Order'"]).each do |address|
        shipment = address.addressable.shipments.first
        # due to an existing bug its possible some orders may have no shipment
        shipment = order.shipments.create if shipment.nil?
        shipment.address = address
        shipment.save
      end
    end
  end

  def self.down
  end
end