class UpdateShipmentStateForCanceledOrders < ActiveRecord::Migration
  def up
    shipments = Spree::Shipment.joins(:order).
      where("spree_orders.state = 'canceled'")

    if Spree::Shipment.connection.adapter_name.eql?('SQLite3')
      shipments.update_all("state = 'cancelled'")
    end
  end

  def down
  end
end
