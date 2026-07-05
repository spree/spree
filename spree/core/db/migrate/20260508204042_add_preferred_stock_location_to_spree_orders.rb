class AddPreferredStockLocationToSpreeOrders < ActiveRecord::Migration[7.2]
  def change
    add_reference :spree_orders, :preferred_stock_location
  end
end
