# This migration comes from spree (originally 20210921090344)
class AddUniqueStockItemStockLocationVariantDeletedAtIndex < ActiveRecord::Migration[5.2]
  def change
    add_index :spree_stock_items, [:stock_location_id, :variant_id, :deleted_at], name: 'stock_item_by_loc_var_id_deleted_at', unique: true
  end
end
