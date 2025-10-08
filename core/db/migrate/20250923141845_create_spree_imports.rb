class CreateSpreeImports < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_imports do |t|
      t.belongs_to :user, null: false
      t.belongs_to :owner, polymorphic: true, null: false

      t.string :status, null: false, index: true

      t.string :number, limit: 32, null: false, index: { unique: true }
      t.string :type, null: false, index: true

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
      t.belongs_to :mappable, polymorphic: true

      t.string :import_type, null: false, index: true

      t.string :original_column_key, null: false
      t.string :original_column_presentation, null: false
      t.string :column, null: false

      t.timestamps
    end

    add_index :spree_import_mappings, [:mappable_type, :mappable_id, :import_type, :original_column_key], unique: true
  end
end
