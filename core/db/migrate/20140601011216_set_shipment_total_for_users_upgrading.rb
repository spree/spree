class SetShipmentTotalForUsersUpgrading < ActiveRecord::Migration
  def up
    # NOTE You might not need this at all unless you're upgrading from Spree 2.1.x
    # or below. For those upgrading this should populate the Order#shipment_total
    # for legacy orders
    Spree::Order.complete.where('shipment_total = ?', 0).includes(:shipments).find_each do |order|
      order.update_column(:shipment_total, order.shipments.sum(:cost))
    end
  end
end
