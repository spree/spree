class CreateSpreeMetafields < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_metafield_definitions do |t|
      t.string :type, null: false, index: true
      t.string :namespace, null: false
      t.string :key, null: false
      t.string :name, null: false
      t.string :resource_type, null: false
      t.string :display_on, null: false, default: 'both', index: true
      t.timestamps

      t.index [:resource_type, :namespace, :key], unique: true
    end

    create_table :spree_metafields do |t|
      t.references :resource, polymorphic: true, null: false, index: true
      t.references :metafield_definition, null: false, index: true
      t.text :value, null: false

      t.timestamps

      t.index [:resource_type, :resource_id, :metafield_definition_id], name: 'index_metafields_on_resource_and_definition', unique: true
    end
  end
end
