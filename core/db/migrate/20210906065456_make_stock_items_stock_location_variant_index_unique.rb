class MakeStockItemsStockLocationVariantIndexUnique < ActiveRecord::Migration[5.2]
  def change
    remove_index :spree_stock_items, [:stock_location_id, :variant_id], name: 'stock_item_by_loc_and_var_id'
    add_index :spree_stock_items, [:stock_location_id, :variant_id], name: 'stock_item_by_loc_and_var_id', unique: true
  end
end
