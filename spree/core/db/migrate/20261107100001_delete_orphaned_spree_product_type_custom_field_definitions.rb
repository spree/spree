class DeleteOrphanedSpreeProductTypeCustomFieldDefinitions < ActiveRecord::Migration[8.1]
  # Deleting a custom field definition used to leave its product type join rows behind.
  # Rows pointing at a missing definition made serializing the product type raise.
  def up
    execute <<~SQL.squish
      DELETE FROM spree_product_type_custom_field_definitions
      WHERE custom_field_definition_id NOT IN (SELECT id FROM spree_custom_field_definitions)
    SQL
  end

  def down; end
end
