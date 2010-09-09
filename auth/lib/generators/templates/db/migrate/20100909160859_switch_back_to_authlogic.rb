class SwitchBackToAuthlogic < ActiveRecord::Migration
  def self.up

    change_table(:users) do |t|

      t.rename :encrypted_password, :crypted_password
      t.rename :password_salt, :salt
      t.rename :remember_created_at, :remember_token_expires_at
      t.rename :authentication_token, :persistence_token
      t.rename :reset_password_token, :single_access_token
      t.rename :sign_in_count, :login_count
      t.rename :current_sign_in_at, :current_login_at
      t.rename :last_sign_in_at, :last_login_at
      t.rename :current_sign_in_ip, :current_login_ip
      t.rename :last_sign_in_ip, :last_login_ip

      t.string :perishable_token
      t.integer :failed_login_count, :default => 0, :null => false
      t.datetime :last_request_at
      t.string :login

    end

  end

  def self.down
  end
end
