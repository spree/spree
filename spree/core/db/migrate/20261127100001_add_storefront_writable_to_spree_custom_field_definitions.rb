class AddStorefrontWritableToSpreeCustomFieldDefinitions < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_custom_field_definitions, :storefront_writable, :boolean, default: false, null: false
  end
end
