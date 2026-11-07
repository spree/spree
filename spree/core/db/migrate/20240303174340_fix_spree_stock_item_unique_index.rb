class FixSpreeStockItemUniqueIndex < ActiveRecord::Migration[6.1]
  def change
    remove_index :spree_stock_items, name: 'stock_item_by_loc_var_id_deleted_at' if index_exists?(:spree_stock_items, [:stock_location_id, :variant_id], name: 'stock_item_by_loc_var_id_deleted_at')

    unless index_exists?(:spree_stock_items, ['variant_id', 'stock_location_id'], name: 'index_spree_stock_items_unique_without_deleted_at')
      # MySQL and MariaDB don't support partial indexes, and MariaDB rejects
      # functional key parts too. Index a stored generated column instead,
      # which both accept.
      if Spree.mysql?
        reversible do |dir|
          dir.up do
            unless column_exists?(:spree_stock_items, :deleted_at_key)
              execute <<-SQL
                ALTER TABLE spree_stock_items
                ADD COLUMN deleted_at_key DATETIME
                AS (COALESCE(deleted_at, CAST('1970-01-01' AS DATETIME))) STORED
              SQL
            end
            add_index :spree_stock_items, %w[stock_location_id variant_id deleted_at_key],
                      name: 'index_spree_stock_items_unique_without_deleted_at', unique: true
          end

          dir.down do
            remove_index :spree_stock_items, name: :index_spree_stock_items_unique_without_deleted_at
            remove_column :spree_stock_items, :deleted_at_key if column_exists?(:spree_stock_items, :deleted_at_key)
          end
        end
      else
        add_index(
          :spree_stock_items,
          ['variant_id', 'stock_location_id'],
          name: 'index_spree_stock_items_unique_without_deleted_at',
          unique: true,
          where: 'deleted_at IS NULL',
        )
      end
    end
  end
end
