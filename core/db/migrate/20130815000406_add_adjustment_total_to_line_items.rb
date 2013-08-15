class AddAdjustmentTotalToLineItems < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :adjustment_total, :decimal, :precision => 10, :scale => 2, :default => 0.0
  end
end
