class ChangeReturnItemPreTaxAmountToAmount < ActiveRecord::Migration
  def change
    # set pre_tax_amount on shipments to discounted_amount - included_tax_total
    # so that the null: false option on the shipment pre_tax_amount doesn't generate
    # errors.
    #
    execute(<<-SQL)
      UPDATE spree_return_items
      SET pre_tax_amount = pre_tax_amount + included_tax_total;
    SQL

    rename_column :spree_return_items, :pre_tax_amount, :amount
  end
end
