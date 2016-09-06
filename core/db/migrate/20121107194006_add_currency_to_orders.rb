class AddCurrencyToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_orders, :currency, :string
  end
end
