# Marks the definitions merchants may build automatic collection rules on.
class AddCollectionConditionToSpreeCustomFieldDefinitions < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_custom_field_definitions, :collection_condition, :boolean, default: false, null: false
  end
end
