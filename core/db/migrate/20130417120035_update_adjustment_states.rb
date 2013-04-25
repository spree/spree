class UpdateAdjustmentStates < ActiveRecord::Migration
  def up
    Spree::Order.complete.each do |order|
      order.adjustments.update_all(:state => 'closed')
    end

    Spree::Shipment.shipped.each do |shipment|
      shipment.adjustment.update_column(:state, 'finalized') if shipment.adjustment
    end

    Spree::Adjustment.where(:state => nil).update_all(:state => 'open')
  end

  def down
  end
end
