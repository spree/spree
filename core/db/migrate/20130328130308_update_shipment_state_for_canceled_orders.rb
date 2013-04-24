class UpdateShipmentStateForCanceledOrders < ActiveRecord::Migration
  def up
    shipments = Spree::Shipment.joins(:order).
      where("spree_orders.state = 'canceled'")
    case Spree::Shipment.connection.adapter_name
    when "SQLite3"
      shipments.update_all("state = 'cancelled'")
    when "MySQL" || "PostgreSQL"
      shipments.update_all("spree_shipments.state = 'cancelled'")
    end
  end

  def down
  end
end
