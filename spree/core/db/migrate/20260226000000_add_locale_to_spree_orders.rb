class AddLocaleToSpreeOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_orders, :locale, :string
  end
end
