class CreateSpreeCustomers < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_customers do |t|
      t.string :email, null: false
      t.string :password_digest
      t.string :first_name
      t.string :last_name
      t.string :phone
      t.string :selected_locale
      t.boolean :accepts_email_marketing
      t.bigint :bill_address_id
      t.bigint :ship_address_id
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

    add_index :spree_customers, :email, unique: true
    add_index :spree_customers, :bill_address_id
    add_index :spree_customers, :ship_address_id
    add_index :spree_customers, :accepts_email_marketing
  end
end
