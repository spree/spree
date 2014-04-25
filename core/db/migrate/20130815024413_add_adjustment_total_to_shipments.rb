class AddAdjustmentTotalToShipments < ActiveRecord::Migration
  def change
    add_column :spree_shipments, :adjustment_total, :decimal, :precision => 10, :scale => 2, :default => 0.0 unless ActiveRecord::Base.connection.column_exists?(:spree_shipments, :adjustment_total)
  end
end
