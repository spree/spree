class CreateSpreeRefreshTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_refresh_tokens do |t|
      t.string :token, null: false
      t.references :user, polymorphic: true, null: false
      t.datetime :expires_at, null: false
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    add_index :spree_refresh_tokens, :token, unique: true
    add_index :spree_refresh_tokens, :expires_at
    add_index :spree_refresh_tokens, [:user_type, :user_id], name: 'idx_refresh_tokens_user'
  end
end
