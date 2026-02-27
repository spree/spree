class AddTokenDigestToSpreeApiKeys < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_api_keys, :token_digest, :string
    add_column :spree_api_keys, :token_prefix, :string

    add_index :spree_api_keys, :token_digest, unique: true

    # Replace the unconditional unique index on token with one that only covers
    # non-NULL values (publishable keys). Secret keys store token as NULL
    # and use token_digest for lookups instead.
    change_column_null :spree_api_keys, :token, true
    remove_index :spree_api_keys, :token
    if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
      # MySQL doesn't support partial indexes, but treats NULL as distinct
      # in unique indexes so multiple secret keys with NULL token are allowed
      add_index :spree_api_keys, :token, unique: true
    else
      add_index :spree_api_keys, :token, unique: true, where: 'token IS NOT NULL'
    end
  end
end
