class BackfillLineItemPreTaxAmount < ActiveRecord::Migration
  def change
    # set pre_tax_amount to discounted_amount - included_tax_total
    execute(<<-SQL)
      UPDATE spree_line_items
      SET pre_tax_amount = ((price * quantity) + promo_total) - included_tax_total
      WHERE pre_tax_amount IS NULL;
    SQL
  end
end
