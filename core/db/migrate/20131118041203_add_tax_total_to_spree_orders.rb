class AddTaxTotalToSpreeOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :tax_total, :decimal, precision: 10, scale: 2, default: 0.0, null: false
  end
end
