class CreateSpreeProductsStores < ActiveRecord::Migration[5.2]
  def up
    unless table_exists?(:spree_products_stores)
      create_table :spree_products_stores do |t|
        t.references :product, index: true
        t.references :store,  index: true
        t.timestamps

        t.index [:product_id, :store_id], unique: true
      end

      stores = Spree::Store.all
      product_ids = Spree::Product.with_deleted.order(:id).ids

      stores.find_each do |store|
        prepared_values = product_ids.map { |id| "(#{id}, #{store.id}, '#{Time.current.to_s(:db)}', '#{Time.current.to_s(:db)}')" }.join(', ')
        next if prepared_values.empty?

        begin
          execute "INSERT INTO spree_products_stores (product_id, store_id, created_at, updated_at) VALUES #{prepared_values};"
        rescue ActiveRecord::RecordNotUnique; end
      end
    end
  end

  def down
    drop_table :spree_products_stores
  end
end
