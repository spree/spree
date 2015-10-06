class CreateSpreeShippingMethodsStockLocations < ActiveRecord::Migration
  def change
    create_table :spree_shipping_methods_stock_locations do |t|
      t.belongs_to :shipping_method
      t.belongs_to :stock_location
    end
  end
end
