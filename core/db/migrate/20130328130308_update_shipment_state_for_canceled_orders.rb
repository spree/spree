class UpdateShipmentStateForCanceledOrders < ActiveRecord::Migration
  def up
    Spree::Shipment.joins(:order).where("spree_orders.state = 'canceled'").update_all("spree_shipments.state = 'canceled'")
  end

  def down
  end
end