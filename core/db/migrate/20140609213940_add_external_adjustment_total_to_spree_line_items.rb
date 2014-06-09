class AddExternalAdjustmentTotalToSpreeLineItems < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :external_adjustment_total, :decimal, precision: 10, scale: 2, null: false, default: 0.0
  end
end
