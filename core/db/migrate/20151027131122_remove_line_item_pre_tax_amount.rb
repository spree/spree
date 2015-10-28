class RemoveLineItemPreTaxAmount < ActiveRecord::Migration
  def up
    execute <<-SQL
      UPDATE spree_line_items
      SET included_tax_total = price * quantity + taxable_adjustment_total - pre_tax_amount;
    SQL

    remove_column :spree_line_items, :pre_tax_amount
  end

  def down
    add_column :spree_line_items, :pre_tax_amount,
      :decimal, precision: 12, scale: 4, default: 0.0, null: false

    execute <<-SQL
      UPDATE spree_line_items
      SET pre_tax_amount = price * quantity + taxable_adjustment_total - included_tax_total;
    SQL
  end
end
