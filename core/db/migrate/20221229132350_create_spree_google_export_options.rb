class CreateSpreeGoogleExportOptions < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_google_export_options do |t|
      t.belongs_to :spree_store, foreign_key: true

      keys = [:material, :brand, :gender, :condition, :gtin, :mpn, :adult, :multipack, :is_bundle, :color, :pattern,
              :size, :item_group_id]

      keys.each do |key|
        t.boolean key, default: false
      end

      t.timestamps
    end
  end
end
