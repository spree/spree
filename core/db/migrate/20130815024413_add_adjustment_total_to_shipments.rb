class AddAdjustmentTotalToShipments < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_shipments, :adjustment_total, :decimal, precision: 10, scale: 2, default: 0.0
  end
end
