class CreateSpreeSellerRequirementCustomFields < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_seller_requirement_custom_fields do |t|
      t.references :seller_requirement, null: false, index: false
      t.references :custom_field_definition, null: false

      t.timestamps
    end

    # A requirement asks for a field once; the pair is the row's identity.
    add_index :spree_seller_requirement_custom_fields,
              [:seller_requirement_id, :custom_field_definition_id],
              unique: true, name: 'idx_seller_requirement_custom_fields_uniqueness'
  end
end
