class SwitchToDevise < ActiveRecord::Migration
  def self.up
    change_table(:users) do |t|
      t.rename :crypted_password, :encrypted_password
      t.rename :salt, :password_salt
      t.rename :remember_token_expires_at, :remember_created_at
      t.rename :persistence_token, :authentication_token
      t.rename :single_access_token, :reset_password_token
      t.remove :perishable_token
      t.rename :login_count, :sign_in_count
      t.remove :failed_login_count
      t.remove :last_request_at
      t.rename :current_login_at, :current_sign_in_at
      t.rename :last_login_at, :last_sign_in_at
      t.rename :current_login_ip, :current_sign_in_ip
      t.rename :last_login_ip, :last_sign_in_ip
      t.remove :login
      t.remove :openid_identifier
      t.remove :api_key
    end
    drop_table :open_id_authentication_associations
    drop_table :open_id_authentication_nonces

    add_index :users, :email,                :unique => true
    add_index :users, :reset_password_token, :unique => true
  end

  def self.down
    # no going back!
  end
end