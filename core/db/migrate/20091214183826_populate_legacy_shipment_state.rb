class PopulateLegacyShipmentState < ActiveRecord::Migration
  # Hack to allow for legacy migrations
  class Shipment < ActiveRecord::Base
  end

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
