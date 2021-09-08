class AddUniqueStockItemStockLocationVariantBackordIndex < ActiveRecord::Migration[5.2]
  def change
    add_index :spree_stock_items, [:stock_location_id, :variant_id, :backorderable], name: 'stock_item_by_loc_var_id_and_backorderable', unique: true
  end
end
