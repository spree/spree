class AddUniqueIndexToSpreeProductsStores < ActiveRecord::Migration[7.2]
  def up
    remove_index :spree_products_stores, %i[product_id store_id] if index_exists?(:spree_products_stores, %i[product_id store_id])

    add_index :spree_products_stores, %i[channel_id product_id store_id],
              unique: true, name: 'index_spree_products_stores_on_channel_product_store'
  end

  def down
    remove_index :spree_products_stores, name: 'index_spree_products_stores_on_channel_product_store'
    add_index :spree_products_stores, %i[product_id store_id], unique: true
  end
end
