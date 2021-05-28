class CreateSpreeProductsStores < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_products_stores, id: :serial do |t|
      t.references :product, index: true
      t.references :store,  index: true
      t.timestamps
    end

    add_index :spree_products_stores, [:product_id, :store_id], unique: true

    stores = Spree::Store.all
    product_ids = Spree::Product.with_deleted.order(:id).ids

    stores.find_each do |store|
      prepared_values = product_ids.map { |id| "(#{id}, #{store.id}, '#{Time.current.to_s(:db)}', '#{Time.current.to_s(:db)}')" }.join(', ')
      next if prepared_values.empty?

      execute "INSERT INTO spree_products_stores (product_id, store_id, created_at, updated_at) VALUES #{prepared_values};"
    end
  end
end
