class CreateDoorkeeperTables < ActiveRecord::Migration[5.1]
  def change
    create_table :spree_oauth_applications do |t|
      t.string  :name,         null: false
      t.string  :uid,          null: false
      t.string  :secret,       null: false
      t.text    :redirect_uri, null: false
      t.string  :scopes,       null: false, default: ''
      t.boolean :confidential, null: false, default: true
      t.timestamps             null: false
    end

    add_index :spree_oauth_applications, :uid, unique: true

    create_table :spree_oauth_access_grants do |t|
      t.integer  :resource_owner_id, null: false
      t.references :application,     null: false
      t.string   :token,             null: false
      t.integer  :expires_in,        null: false
      t.text     :redirect_uri,      null: false
      t.datetime :created_at,        null: false
      t.datetime :revoked_at
      t.string   :scopes
    end

    add_index :spree_oauth_access_grants, :token, unique: true
    add_foreign_key(
      :spree_oauth_access_grants,
      :spree_oauth_applications,
      column: :application_id
    )

    create_table :spree_oauth_access_tokens do |t|
      t.integer  :resource_owner_id
      t.references :application

      # If you use a custom token generator you may need to change this column
      # from string to text, so that it accepts tokens larger than 255
      # characters. More info on custom token generators in:
      # https://github.com/doorkeeper-gem/doorkeeper/tree/v3.0.0.rc1#custom-access-token-generator
      #
      # t.text     :token,             null: false
      t.string   :token,                  null: false

      t.string   :refresh_token
      t.integer  :expires_in
      t.datetime :revoked_at
      t.datetime :created_at,             null: false
      t.string   :scopes

      # If there is a previous_refresh_token column,
      # refresh tokens will be revoked after a related access token is used.
      # If there is no previous_refresh_token column,
      # previous tokens are revoked as soon as a new access token is created.
      # Comment out this line if you'd rather have refresh tokens
      # instantly revoked.
      t.string   :previous_refresh_token, null: false, default: ""
    end

    add_index :spree_oauth_access_tokens, :token, unique: true
    add_index :spree_oauth_access_tokens, :resource_owner_id
    add_index :spree_oauth_access_tokens, :refresh_token, unique: true
    add_foreign_key(
      :spree_oauth_access_tokens,
      :spree_oauth_applications,
      column: :application_id
    )
  end
end
