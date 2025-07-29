class CreateSpreeMetafields < ActiveRecord::Migration[8.0]
  def change
    create_table :spree_metafield_definitions do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.string :kind, null: false, index: true
      t.string :owner_type, null: false
      t.string :display_on, null: false, default: 'both', index: true
      t.timestamps

      t.index [:owner_type, :key], unique: true
    end

    create_table :spree_metafields do |t|
      t.references :owner, polymorphic: true, null: false, index: true
      t.references :metafield_definition, null: false, index: true
      t.text :value, null: false

      t.timestamps

      t.index [:owner_type, :owner_id, :metafield_definition_id], name: 'index_metafields_on_owner_and_definition', unique: true
    end
  end
end
