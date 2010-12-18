class CreateTokenizedPermissions < ActiveRecord::Migration

  def self.up

    create_table :tokenized_permissions do |t|
      t.integer :permissable_id
      t.string  :permissable_type
      t.string  :token
      t.timestamps
    end

    add_index "tokenized_permissions", ["permissable_id", "permissable_type"], :name => "index_tokenized_name_and_type"
  end

  def self.down
    drop_table :tokenized_permissions
  end
end
