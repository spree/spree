class AddSearchableSortableToSpreeMetafieldDefinitions < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_metafield_definitions, :searchable, :boolean, if_not_exists: true
    add_column :spree_metafield_definitions, :sortable, :boolean, if_not_exists: true

    add_index :spree_metafield_definitions, :searchable, if_not_exists: true
    add_index :spree_metafield_definitions, :sortable, if_not_exists: true
  end
end
