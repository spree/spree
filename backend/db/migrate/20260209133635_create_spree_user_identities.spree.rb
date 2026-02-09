# This migration comes from spree (originally 20250923141900)
class CreateSpreeUserIdentities < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_user_identities do |t|
      t.references :user, polymorphic: true, null: false, index: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.json :info
      t.string :access_token
      t.string :refresh_token
      t.datetime :expires_at

      t.timestamps
    end

    add_index :spree_user_identities, [:provider, :uid, :user_type], unique: true, name: 'index_spree_user_identities_on_provider_uid_user_type'
  end
end
