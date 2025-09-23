class CreateSpreeImports < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_imports do |t|
      t.references :user, null: false
      t.references :store, null: false

      t.string :status, null: false, index: true

      t.string :number, limit: 32, null: false
      t.string :type, null: false

      t.timestamps
    end
    add_index :spree_imports, [:store_id, :number], unique: true

    create_table :spree_import_mappings do |t|
      t.references :store, null: false
      t.string :import_type, null: false, index: true
      t.string :external_column_key, null: false
      t.string :external_column_presentation, null: false
      t.string :internal_column_key, null: false

      t.timestamps
    end

    add_index :spree_import_mappings, [:store_id, :import_type, :external_column_key], unique: true

    create_table :spree_import_rows do |t|
      t.references :import, null: false
      t.references :item, polymorphic: true

      t.string :status, null: false, index: true
      t.integer :row_number, null: false

      t.text :data, null: false
      t.text :error_message

      t.timestamps
    end
  end
end
