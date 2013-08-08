class CreateShippingMethodStockLocation < ActiveRecord::Migration
  def up
    create_table :spree_shipping_method_stock_locations, :id => false do |t|
      t.integer :shipping_method_id
      t.integer :stock_location_id
    end
  end

  def down
    drop_table :spree_shipping_method_stock_locations
  end
end
