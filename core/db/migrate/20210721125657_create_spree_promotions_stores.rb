class CreateSpreePromotionsStores < ActiveRecord::Migration[5.2]
  def up
    unless table_exists?(:spree_promotions_stores)
      create_table :spree_promotions_stores do |t|
        t.references :promotion, index: true
        t.references :store,  index: true
        t.timestamps

        t.index [:promotion_id, :store_id], unique: true
      end

      stores = Spree::Store.all
      promotion_ids = Spree::Promotion.order(:id).ids

      stores.find_each do |store|
        prepared_values = promotion_ids.map { |id| "(#{id}, #{store.id}, '#{Time.current.to_s(:db)}', '#{Time.current.to_s(:db)}')" }.join(', ')
        next if prepared_values.empty?

        begin
          execute "INSERT INTO spree_promotions_stores (promotion_id, store_id, created_at, updated_at) VALUES #{prepared_values};"
        rescue ActiveRecord::RecordNotUnique; end
      end
    end
  end

  def down
    drop_table :spree_promotions_stores
  end
end
