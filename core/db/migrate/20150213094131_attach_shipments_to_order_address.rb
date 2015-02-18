class AttachShipmentsToOrderAddress < ActiveRecord::Migration
  def up
    Spree::Shipment.where(address: nil).each do |shipment|
      shipment.update_attributes!(address: shipment.order.ship_address)
    end
  end

  def down
  end
end
