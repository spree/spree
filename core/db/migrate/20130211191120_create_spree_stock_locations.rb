class CreateSpreeStockLocations < ActiveRecord::Migration
  def change
    create_table :spree_stock_locations do |t|
      t.string :name
      t.belongs_to :address

      t.timestamps null: false
    end
    add_index :spree_stock_locations, :address_id
  end
end
