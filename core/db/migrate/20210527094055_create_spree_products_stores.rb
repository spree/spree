class CreateSpreeProductsStores < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_products_stores, id: :serial do |t|
      t.references :product, index: true
      t.references :store,  index: true
      t.timestamps
    end

    add_index :spree_products_stores, [:product_id, :store_id], unique: true

    default_store_id = Spree::Store.default.id
    prepared_values = Spree::Product.with_deleted.order(:id).ids.map { |id| "(#{id}, #{default_store_id}, '#{Time.current.to_s(:db)}', '#{Time.current.to_s(:db)}')" }.join(', ')
    return if prepared_values.empty?

    execute "INSERT INTO spree_products_stores (product_id, store_id, created_at, updated_at) VALUES #{prepared_values};"
  end
end
