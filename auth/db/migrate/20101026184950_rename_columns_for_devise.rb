class RenameColumnsForDevise < ActiveRecord::Migration
  def up
    return if column_exists?(:spree_users, :password_salt)
    rename_column :spree_users, :crypted_password, :encrypted_password
    rename_column :spree_users, :salt, :password_salt
    rename_column :spree_users, :remember_token_expires_at, :remember_created_at
    rename_column :spree_users, :login_count, :sign_in_count
    rename_column :spree_users, :failed_login_count, :failed_attempts
    rename_column :spree_users, :single_access_token, :reset_password_token
    rename_column :spree_users, :current_login_at, :current_sign_in_at
    rename_column :spree_users, :last_login_at, :last_sign_in_at
    rename_column :spree_users, :current_login_ip, :current_sign_in_ip
    rename_column :spree_users, :last_login_ip, :last_sign_in_ip
    add_column :spree_users, :authentication_token, :string
    add_column :spree_users, :unlock_token, :string
    add_column :spree_users, :locked_at, :datetime
    remove_column :spree_users, :api_key if column_exists?(:spree_users, :api_key)
    remove_column :spree_users, :openid_identifier
  end

  def down
    remove_column :spree_users, :authentication_token
    remove_column :spree_users, :locked_at
    remove_column :spree_users, :unlock_token
    rename_column :spree_users, :last_sign_in_ip, :last_login_ip
    rename_column :spree_users, :current_sign_in_ip, :current_login_ip
    rename_column :spree_users, :last_sign_in_at, :last_login_at
    rename_column :spree_users, :current_sign_in_at, :current_login_at
    rename_column :spree_users, :reset_password_token, :single_access_token
    rename_column :spree_users, :failed_attempts, :failed_login_count
    rename_column :spree_users, :sign_in_count, :login_count
    rename_column :spree_users, :remember_created_at, :remember_token_expires_at
    rename_column :spree_users, :password_salt, :salt
    rename_column :spree_users, :encrypted_password, :crypted_password
    add_column :spree_users, :unlock_token, :string
    add_column :spree_users, :openid_identifier, :string
  end
end
