class PopulateLegacyShipmentState < ActiveRecord::Migration
  def up
    shipments = select_all "SELECT * FROM shipments"
    shipments.each do |shipment|
      if shipment['shipped_at']
        execute "UPDATE shipments SET state = 'shipped'"
      else
        execute "UPDATE shipments SET state = 'pending'"
      end
    end
  end

  def down
  end
end
