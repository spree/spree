class CreateSpreeAdminUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_admin_users do |t|
      t.string :email, null: false
      t.string :password_digest
      t.string :first_name
      t.string :last_name
      t.string :selected_locale
      t.integer :failed_attempts
      t.datetime :locked_at

      if t.respond_to?(:jsonb)
        t.jsonb :public_metadata
        t.jsonb :private_metadata
      else
        t.json :public_metadata
        t.json :private_metadata
      end

      t.timestamps
    end

    add_index :spree_admin_users, :email, unique: true
  end
end
