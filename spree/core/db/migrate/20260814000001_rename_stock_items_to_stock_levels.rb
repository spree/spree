class RenameStockItemsToStockLevels < ActiveRecord::Migration[8.1]
  # StockItem becomes StockLevel (docs/plans/6.0-typed-stock-movements.md).
  # The table and both foreign keys are renamed in place, so existing rows
  # carry over untouched. Rails renames the default-named indexes along with
  # the table and the columns; the four custom names below have to be moved
  # by hand.
  def up
    rename_table :spree_stock_items, :spree_stock_levels
    rename_column :spree_stock_movements, :stock_item_id, :stock_level_id
    rename_column :spree_stock_reservations, :stock_item_id, :stock_level_id

    rename_index :spree_stock_levels, 'stock_item_by_loc_var_id_deleted_at', 'stock_level_by_loc_var_id_deleted_at'
    rename_index :spree_stock_levels, 'stock_item_by_loc_and_var_id', 'stock_level_by_loc_and_var_id'
    rename_index :spree_stock_reservations, 'idx_stock_reservations_item_line_item', 'idx_stock_reservations_level_line_item'

    rename_partial_uniqueness_index(
      from: 'index_spree_stock_items_unique_without_deleted_at',
      to: 'index_spree_stock_levels_unique_without_deleted_at'
    )
  end

  def down
    rename_partial_uniqueness_index(
      from: 'index_spree_stock_levels_unique_without_deleted_at',
      to: 'index_spree_stock_items_unique_without_deleted_at'
    )

    rename_index :spree_stock_reservations, 'idx_stock_reservations_level_line_item', 'idx_stock_reservations_item_line_item'
    rename_index :spree_stock_levels, 'stock_level_by_loc_and_var_id', 'stock_item_by_loc_and_var_id'
    rename_index :spree_stock_levels, 'stock_level_by_loc_var_id_deleted_at', 'stock_item_by_loc_var_id_deleted_at'

    rename_column :spree_stock_reservations, :stock_level_id, :stock_item_id
    rename_column :spree_stock_movements, :stock_level_id, :stock_item_id
    rename_table :spree_stock_levels, :spree_stock_items
  end

  private

  # rename_index rebuilds the index from its columns on adapters without a
  # native rename, which silently drops the partial condition. This one is a
  # uniqueness index over live rows only, so it is recreated explicitly.
  def rename_partial_uniqueness_index(from:, to:)
    remove_index :spree_stock_levels, name: from

    if connection.adapter_name.downcase.start_with?('mysql')
      execute <<~SQL
        CREATE UNIQUE INDEX #{to}
        ON spree_stock_levels(
          stock_location_id,
          variant_id,
          (COALESCE(deleted_at, CAST('1970-01-01' AS DATETIME)))
        );
      SQL
    else
      add_index :spree_stock_levels, %w[variant_id stock_location_id], name: to, unique: true, where: 'deleted_at IS NULL'
    end
  end
end
