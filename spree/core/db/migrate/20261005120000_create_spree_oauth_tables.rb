# OAuth 2.1 authorization server tables. Separate from any OAuth Spree
# carried before 5.4: those served password and client-credentials grants for
# the legacy API, and nothing migrates forward.
class CreateSpreeOauthTables < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_oauth_applications do |t|
      t.string :name, null: false
      t.string :uid, null: false
      # Null for a public client, which is every MCP client: they run in a
      # browser or on a vendor's server and cannot hold a secret, which is
      # why PKCE is mandatory rather than optional here.
      t.string :secret
      t.text :redirect_uri
      t.string :scopes, null: false, default: ''
      t.boolean :confidential, null: false, default: false
      t.references :store, null: false, index: true
      t.timestamps
    end

    add_index :spree_oauth_applications, :uid, unique: true

    create_table :spree_oauth_access_grants do |t|
      t.references :resource_owner, polymorphic: true, null: false, index: true
      t.references :application, null: false, index: true
      t.string :token, null: false
      t.integer :expires_in, null: false
      t.text :redirect_uri
      t.string :scopes, null: false, default: ''
      t.datetime :revoked_at
      t.string :code_challenge
      t.string :code_challenge_method
      # RFC 8707: what the grant was requested for, carried to the token so
      # the audience can be checked on every call. The column name is
      # Doorkeeper's — its `resource_indicators_supported?` detects the
      # feature by this column's presence.
      t.text :resource
      t.timestamps
    end

    add_index :spree_oauth_access_grants, :token, unique: true

    create_table :spree_oauth_access_tokens do |t|
      t.references :resource_owner, polymorphic: true, index: true
      t.references :application, index: true
      # Text rather than string: tokens are hashed, and a hash outgrows 255
      # characters under some configurations.
      t.text :token, null: false
      t.text :refresh_token
      t.integer :expires_in
      t.datetime :revoked_at
      t.string :scopes
      t.string :previous_refresh_token, null: false, default: ''
      t.text :resource
      t.timestamps
    end

    add_index :spree_oauth_access_tokens, :refresh_token, unique: true
    # Hashed tokens are long, so the lookup index covers a prefix on MySQL,
    # where a full-length text index is rejected.
    if connection.adapter_name.match?(/mysql/i)
      add_index :spree_oauth_access_tokens, :token, unique: true, length: 255
    else
      add_index :spree_oauth_access_tokens, :token, unique: true
    end
  end
end
