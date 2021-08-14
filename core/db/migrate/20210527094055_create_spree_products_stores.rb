class CreateSpreeProductsStores < ActiveRecord::Migration[5.2]
  def up
    if table_exists?(:spree_products_stores)
      unless index_exists?(:spree_products_stores, [:product_id, :store_id], unique: true)
        add_index :spree_products_stores, [:product_id, :store_id], unique: true
      end
      unless column_exists?(:spree_products_stores, :created_at)
        add_timestamps :spree_products_stores
      end
    else
      create_table :spree_products_stores do |t|
        t.references :product, index: true
        t.references :store,  index: true
        t.timestamps

        t.index [:product_id, :store_id], unique: true
      end

      stores = Spree::Store.all
      product_ids = Spree::Product.with_deleted.order(:id).ids

      if product_ids.any? && Spree::StoreProduct.respond_to?(:insert_all)
        stores.find_each do |store|
          records = product_ids.map { |product_id| { product_id: product_id, store_id: store.id } }

          # Rails 5 does not have insert_all
          Spree::StoreProduct.insert_all(records)
        end
      end
    end
  end

  def down
    drop_table :spree_products_stores
  end
end
