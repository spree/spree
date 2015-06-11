class IncreaseScaleOnPreTaxAmounts < ActiveRecord::Migration
  def change
    change_column :spree_line_items, :pre_tax_amount, :decimal, precision: 12, scale: 4, default: 0.0, null: false
    change_column :spree_shipments, :pre_tax_amount, :decimal, precision: 12, scale: 4, default: 0.0, null: false
  end
end
