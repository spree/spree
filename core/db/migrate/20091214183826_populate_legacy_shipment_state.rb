# Hack to allow for legacy migrations
class Shipment < ActiveRecord::Base; end;

class PopulateLegacyShipmentState < ActiveRecord::Migration
  def up
    Shipment.all.each do |shipment|
      if shipment.shipped_at
        shipment.state = 'shipped'
      else
        shipment.state = 'pending'
      end
      shipment.save
    end
  end

  def down
  end
end
