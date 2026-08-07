class CreateSpreeProductTypeCustomFieldDefinitions < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_product_type_custom_field_definitions do |t|
      t.references :product_type, null: false, index: false
      t.references :custom_field_definition, null: false
      t.boolean :required, null: false, default: false
      t.integer :sort_order, null: false, default: 0

      t.timestamps
    end

    add_index :spree_product_type_custom_field_definitions,
              [:product_type_id, :custom_field_definition_id],
              unique: true,
              name: 'idx_product_type_cf_defs_unique'
  end
end
