class CreateSpreeGoogleExportOptions < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_google_export_options do |t|
      t.integer :store

      t.boolean :material, default: false
      t.boolean :brand, default: false
      t.boolean :gender, default: false

      t.timestamps
    end
  end
end
