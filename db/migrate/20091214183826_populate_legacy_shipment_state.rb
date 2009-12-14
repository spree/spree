class PopulateLegacyShipmentState < ActiveRecord::Migration
  def self.up
    Shipment.all.each do |shipment|
      if shipment.shipped_at
        shipment.state = "shipped"
      else
        shipment.state = "pending"
      end
      shipment.save
    end
  end

  def self.down
  end
end
