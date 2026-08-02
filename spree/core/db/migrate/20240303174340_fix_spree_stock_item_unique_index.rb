class FixSpreeStockItemUniqueIndex < ActiveRecord::Migration[6.1]
  INDEX_NAME = 'index_spree_stock_items_unique_without_deleted_at'.freeze
  GENERATED_COLUMN = 'deleted_at_not_null'.freeze

  def up
    if index_exists?(:spree_stock_items, [:stock_location_id, :variant_id], name: 'stock_item_by_loc_var_id_deleted_at')
      remove_index :spree_stock_items, name: 'stock_item_by_loc_var_id_deleted_at'
    end

    return if index_exists?(:spree_stock_items, ['variant_id', 'stock_location_id'], name: INDEX_NAME)

    connection = ActiveRecord::Base.connection

    if connection.adapter_name == 'Mysql2'
      # MySQL/MariaDB don't support partial indexes, so we fold a NULL
      # +deleted_at+ into a constant to keep active rows unique while letting
      # soft-deleted rows repeat.
      if connection.mariadb?
        # MariaDB has no functional key parts, so index a persistent generated
        # column that carries the coalesced value.
        execute <<-SQL
          ALTER TABLE spree_stock_items
          ADD COLUMN #{GENERATED_COLUMN} DATETIME(6) AS (COALESCE(deleted_at, DATE'1970-01-01')) PERSISTENT
        SQL
        execute <<-SQL
          CREATE UNIQUE INDEX #{INDEX_NAME}
          ON spree_stock_items(stock_location_id, variant_id, #{GENERATED_COLUMN})
        SQL
      else
        execute <<-SQL
          CREATE UNIQUE INDEX #{INDEX_NAME}
          ON spree_stock_items(
            stock_location_id,
            variant_id,
            (COALESCE(deleted_at, CAST('1970-01-01' AS DATETIME)))
          )
        SQL
      end
    else
      add_index(
        :spree_stock_items,
        ['variant_id', 'stock_location_id'],
        name: INDEX_NAME,
        unique: true,
        where: 'deleted_at IS NULL'
      )
    end
  end

  def down
    remove_index :spree_stock_items, name: INDEX_NAME, if_exists: true

    if column_exists?(:spree_stock_items, GENERATED_COLUMN)
      remove_column :spree_stock_items, GENERATED_COLUMN
    end
  end
end
