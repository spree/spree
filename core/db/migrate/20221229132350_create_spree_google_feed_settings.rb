class CreateSpreeGoogleFeedSettings < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_google_feed_settings do |t|
      t.references :spree_store

      keys = [:material, :brand, :gender, :condition, :gtin, :mpn, :adult, :multipack, :is_bundle, :color, :pattern,
              :size, :item_group_id]

      keys.each do |key|
        t.boolean key, default: false
      end

      t.timestamps
    end
  end
end
