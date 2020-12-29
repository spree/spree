class CreateSpreeStockItems < ActiveRecord::Migration[4.2]
  def change
    create_table :spree_stock_items do |t|
      t.belongs_to :stock_location
      t.belongs_to :variant
      t.integer :count_on_hand, null: false, default: 0
      t.integer :lock_version

      t.timestamps null: false, precision: 6
    end
    add_index :spree_stock_items, :stock_location_id
    add_index :spree_stock_items, [:stock_location_id, :variant_id], name: 'stock_item_by_loc_and_var_id'
  end
end
