class RemoveLineItemPreTaxAmount < ActiveRecord::Migration
  def change
    execute <<-SQL
      UPDATE spree_line_items
      SET included_tax_total = price * quantity + promo_total - pre_tax_amount;
    SQL
    remove_column :spree_line_items, :pre_tax_amount
  end
end
