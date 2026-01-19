class AddStatisticsToStoreProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :spree_products_stores, :units_sold_count, :integer, default: 0, null: false
    add_column :spree_products_stores, :revenue, :decimal, precision: 10, scale: 2, default: 0, null: false

    add_index :spree_products_stores, [:store_id, :units_sold_count],
              name: 'index_products_stores_on_store_and_units_sold'
    add_index :spree_products_stores, [:store_id, :revenue],
              name: 'index_products_stores_on_store_and_revenue'
  end
end
