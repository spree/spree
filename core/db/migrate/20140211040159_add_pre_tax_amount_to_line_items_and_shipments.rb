class AddPreTaxAmountToLineItemsAndShipments < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :pre_tax_amount, :decimal, precision: 8, scale: 2
    add_column :spree_shipments, :pre_tax_amount, :decimal, precision: 8, scale: 2
  end
end
