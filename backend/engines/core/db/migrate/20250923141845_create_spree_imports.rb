class CreateSpreeImports < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_imports do |t|
      t.belongs_to :user, null: false
      t.belongs_to :owner, polymorphic: true, null: false

      t.string :status, null: false, index: true

      t.string :number, limit: 32, null: false, index: { unique: true }
      t.string :type, null: false, index: true

      t.text :processing_errors

      t.text :preferences

      t.integer :rows_count, null: false, default: 0

      t.timestamps
    end

    create_table :spree_import_rows do |t|
      t.belongs_to :import, null: false
      t.belongs_to :item, polymorphic: true

      t.string :status, null: false, index: true
      t.integer :row_number, null: false

      t.text :data, null: false
      t.text :validation_errors

      t.timestamps
    end

    add_index :spree_import_rows, [:import_id, :row_number], unique: true

    create_table :spree_import_mappings do |t|
      t.belongs_to :import, null: false

      t.string :schema_field, null: false
      t.string :file_column, index: true

      t.timestamps
    end

    add_index :spree_import_mappings, [:import_id, :schema_field], unique: true
  end
end
