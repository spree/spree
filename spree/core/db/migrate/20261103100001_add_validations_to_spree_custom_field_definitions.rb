class AddValidationsToSpreeCustomFieldDefinitions < ActiveRecord::Migration[8.1]
  def change
    change_table :spree_custom_field_definitions do |t|
      if t.respond_to?(:jsonb)
        add_column :spree_custom_field_definitions, :validations, :jsonb
      else
        add_column :spree_custom_field_definitions, :validations, :json
      end
    end

    # New definitions are admin-only unless the merchant asks; existing rows
    # keep the value they were saved with.
    change_column_default :spree_custom_field_definitions, :storefront_visible, from: true, to: false
  end
end
