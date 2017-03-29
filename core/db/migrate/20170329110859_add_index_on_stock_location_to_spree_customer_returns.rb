class AddIndexOnStockLocationToSpreeCustomerReturns < ActiveRecord::Migration[5.0]
  def change
    add_index :spree_customer_returns, :stock_location_id
  end
end
