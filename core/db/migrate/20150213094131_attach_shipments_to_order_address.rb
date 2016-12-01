class AttachShipmentsToOrderAddress < ActiveRecord::Migration[5.0]
  def up
    Spree::Shipment.where(address: nil).each do |shipment|
      shipment.update_attributes!(address: shipment.order.ship_address)
    end
  end

  def down
  end
end
