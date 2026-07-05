class CreateSpreeApiKeys < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_api_keys do |t|
      t.string :name, null: false
      t.string :key_type, null: false
      t.string :token, null: false
      t.references :store, null: false, index: true
      t.references :created_by, null: true, polymorphic: true, index: true
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.references :revoked_by, null: true, polymorphic: true, index: true
      t.timestamps
    end

    add_index :spree_api_keys, :token, unique: true
    add_index :spree_api_keys, :key_type
    add_index :spree_api_keys, [:store_id, :key_type]
  end
end
