class CreateSpreeCustomersAndAdminUsers < ActiveRecord::Migration[7.2]
  def up
    # spree_admin_users already exists on any pre-6.0 install that split admins
    # out. Create it only when absent, but always ensure the has_secure_password
    # column exists. It is added alongside a legacy encrypted_password (never
    # renamed), so Devise digests survive for the
    # spree:upgrade:migrate_users_to_customers backfill.
    unless table_exists?(:spree_admin_users)
      create_table :spree_admin_users do |t|
        t.string :email, null: false
        t.string :password_digest
        t.string :first_name
        t.string :last_name
        t.string :selected_locale
        t.integer :failed_attempts
        t.datetime :locked_at

        t.timestamps
      end

      add_index :spree_admin_users, :email, unique: true
    end

    add_column :spree_admin_users, :password_digest, :string unless column_exists?(:spree_admin_users, :password_digest)

    # spree_customers is new in 6.0 — always created fresh.
    create_table :spree_customers do |t|
      t.string :email, null: false
      t.string :password_digest
      t.string :first_name
      t.string :last_name
      t.string :phone
      t.string :selected_locale
      t.boolean :accepts_email_marketing, null: false
      t.bigint :bill_address_id
      t.bigint :ship_address_id
      t.integer :failed_attempts
      t.datetime :locked_at

      # jsonb on PostgreSQL (binary, indexable); json on MySQL/SQLite.
      t.respond_to?(:jsonb) ? t.jsonb(:metadata) : t.json(:metadata)

      t.timestamps
    end

    add_index :spree_customers, :email, unique: true
    add_index :spree_customers, :bill_address_id
    add_index :spree_customers, :ship_address_id
    add_index :spree_customers, :accepts_email_marketing
  end

  def down
    drop_table :spree_customers

    # Leave spree_admin_users and its password_digest column in place — this
    # migration may have found them already present (upgrade / dummy) and must
    # not drop a table or column it did not create.
  end
end
