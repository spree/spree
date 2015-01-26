class CreateLineItemStockLocations < ActiveRecord::Migration
  def change
    create_table :spree_line_item_stock_locations do |t|
      t.integer :line_item_id
      t.integer :stock_location_id
      t.integer :quantity
      t.timestamps
    end

    add_index :spree_line_item_stock_locations, :line_item_id
  end
end
