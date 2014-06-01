class SetShipmentTotalForUsersUpgrading < ActiveRecord::Migration
  def up
    # NOTE You might not need this at all unless you're upgrading from Spree 2.1.x
    # or below. For those upgrading this should populate the Order#shipment_total
    # for legacy orders
    execute "UPDATE spree_orders
             SET shipment_total = (SELECT SUM(spree_shipments.cost) AS sum_id
                                   FROM spree_shipments
                                   WHERE spree_shipments.order_id = spree_orders.id)
             WHERE spree_orders.completed_at IS NOT NULL AND spree_orders.shipment_total = 0"
  end
end
