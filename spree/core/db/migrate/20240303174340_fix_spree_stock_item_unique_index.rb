class FixSpreeStockItemUniqueIndex < ActiveRecord::Migration[6.1]
  def change
    remove_index :spree_stock_items, name: 'stock_item_by_loc_var_id_deleted_at' if index_exists?(:spree_stock_items, [:stock_location_id, :variant_id], name: 'stock_item_by_loc_var_id_deleted_at')

    unless index_exists?(:spree_stock_items, ['variant_id', 'stock_location_id'], name: 'index_spree_stock_items_unique_without_deleted_at')
      # MySQL doesn't support partial indexes
      if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
        reversible do |dir|
          dir.up do
            add_column :spree_stock_items, :deleted_at_with_default, :virtual, type: :datetime, as: "IFNULL(deleted_at, '1970-01-01 00:00:00')", stored: false
            add_index(
              :spree_stock_items,
              ['variant_id', 'stock_location_id', 'deleted_at_with_default'],
              name: 'index_spree_stock_items_unique_without_deleted_at',
              unique: true,
            )
          end

          dir.down do
            remove_index :spree_stock_items, name: :index_spree_stock_items_unique_without_deleted_at
            remove_column :spree_stock_items, :deleted_at_with_default
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
