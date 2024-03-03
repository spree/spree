class FixSpreeStockItemUniqueIndex < ActiveRecord::Migration[6.1]
  def change
    remove_index :spree_stock_items, name: 'stock_item_by_loc_var_id_deleted_at' if index_exists?(:spree_stock_items, [:stock_location_id, :variant_id], name: 'stock_item_by_loc_var_id_deleted_at')

    add_index(
      :spree_stock_items,
      ['variant_id', 'stock_location_id'],
      name: 'index_spree_stock_items_unique_without_deleted_at',
      unique: true,
      where: 'deleted_at IS NULL',
    ) unless index_exists?(:spree_stock_items, ['variant_id', 'stock_location_id'], name: 'index_spree_stock_items_unique_without_deleted_at')
  end
end
