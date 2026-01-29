# frozen_string_literal: true

class CreateSpreeAdminUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_admin_users do |t|
      t.string :encrypted_password, limit: 128
      t.string :password_salt, limit: 128
      t.string :email
      t.string :remember_token
      t.string :persistence_token
      t.string :reset_password_token
      t.string :perishable_token
      t.integer :sign_in_count, default: 0, null: false
      t.integer :failed_attempts, default: 0, null: false
      t.datetime :last_request_at
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip
      t.string :login
      t.bigint :ship_address_id
      t.bigint :bill_address_id
      t.string :authentication_token
      t.string :unlock_token
      t.datetime :locked_at
      t.datetime :remember_created_at
      t.datetime :reset_password_sent_at
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :spree_admin_users, :email, unique: true
    add_index :spree_admin_users, :deleted_at
  end
end
