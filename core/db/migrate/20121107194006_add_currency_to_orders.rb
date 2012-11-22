class AddCurrencyToOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :currency, :string
  end
end
