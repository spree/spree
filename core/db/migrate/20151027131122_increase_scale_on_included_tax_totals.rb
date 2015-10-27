class IncreaseScaleOnIncludedTaxTotals < ActiveRecord::Migration
  def change
    change_column :spree_line_items, :included_tax_total, :decimal, precision: 12, scale: 4, default: 0.0, null: false
    execute <<-SQL
      UPDATE spree_line_items
      SET included_tax_total = price * quantity + promo_total - pre_tax_amount;
    SQL
    remove_column :spree_line_items, :pre_tax_amount
  end
end
