class RenameColumnsForDevise < ActiveRecord::Migration
  def self.up
    return if column_exists?(:users, :password_salt)
    rename_column :users, :crypted_password, :encrypted_password
    rename_column :users, :salt, :password_salt
    rename_column :users, :remember_token_expires_at, :remember_created_at
    rename_column :users, :login_count, :sign_in_count
    rename_column :users, :failed_login_count, :failed_attempts
    rename_column :users, :single_access_token, :reset_password_token
    rename_column :users, :current_login_at, :current_sign_in_at
    rename_column :users, :last_login_at, :last_sign_in_at
    rename_column :users, :current_login_ip, :current_sign_in_ip
    rename_column :users, :last_login_ip, :last_sign_in_ip
    add_column :users, :authentication_token, :string
    add_column :users, :unlock_token, :string
    add_column :users, :locked_at, :datetime
    remove_column :users, :api_key rescue Exception
    remove_column :users, :openid_identifier
  end

  def self.down
    remove_column :users, :authentication_token
    remove_column :users, :locked_at
    remove_column :users, :unlock_token
    rename_column :table_name, :new_column_name, :column_name
    rename_column :users, :last_sign_in_ip, :last_login_ip
    rename_column :users, :current_sign_in_ip, :current_login_ip
    rename_column :users, :last_sign_in_at, :last_login_at
    rename_column :users, :current_sign_in_at, :current_login_at
    rename_column :users, :reset_password_token, :single_access_token
    rename_column :users, :failed_attempts, :failed_login_count
    rename_column :users, :sign_in_count, :login_count
    rename_column :users, :remember_created_at, :remember_token_expires_at
    rename_column :users, :password_salt, :salt
    rename_column :users, :encrypted_password, :crypted_password
    add_column :users, :unlock_token, :string
    add_column :users, :openid_identifier, :string
  end
end
