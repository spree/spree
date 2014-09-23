class FixAdjustmentOrderPresence < ActiveRecord::Migration
  def change
    say 'Fixing adjustments without direct order reference'
    Spree::Adjustment.where(order: nil).find_each do |adjustment|
      adjustment.udpate_attributes!(adjustable: adjustment.adjustable.order)
    end
  end
end
