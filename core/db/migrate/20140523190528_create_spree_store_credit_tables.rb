class CreateSpreeStoreCreditTables < ActiveRecord::Migration
  def change
    create_table :spree_store_credit_categories do |t|
      t.string :name
      t.timestamps
    end

    create_table :spree_store_credits do |t|
      t.references :user
      t.references :category
      t.references :created_by
      t.integer :type_id
      t.decimal :amount, precision: 8, scale: 2, default: 0.0, null: false
      t.decimal :amount_used, precision: 8, scale: 2, default: 0.0, null: false
      t.decimal :amount_authorized, precision: 8, scale: 2, default: 0.0, null: false
      t.string :currency
      t.text :memo
      t.timestamps
      t.datetime :deleted_at
    end
    add_index :spree_store_credits, :deleted_at
    add_index :spree_store_credits, :user_id
    add_index :spree_store_credits, :type_id

    create_table :spree_store_credit_events do |t|
      t.integer :store_credit_id,    null: false
      t.string  :action,             null: false
      t.integer :originator_id
      t.string  :originator_type
      t.decimal :amount,             precision: 8, scale: 2
      t.decimal :user_total_amount,  precision: 8, scale: 2, default: 0.0, null: false
      t.string  :authorization_code, null: false
      t.timestamps
      t.datetime :deleted_at
    end
    add_index :spree_store_credit_events, :store_credit_id

    create_table :spree_store_credit_types do |t|
      t.string :name
      t.integer :priority
      t.timestamps
    end
    add_index :spree_store_credit_types, :priority

    default_type = Spree::StoreCreditType.find_or_create_by(name: 'Expiring', priority: 1)
    Spree::StoreCredit.update_all(type_id: default_type.id)
    Spree::StoreCreditType.find_or_create_by(name: 'Non-expiring', priority: 2)
    Spree::ReimbursementType.find_or_create_by(name: 'Store Credit', type: 'Spree::ReimbursementType::StoreCredit')

    return if Spree::PaymentMethod.find_by_type("Spree::PaymentMethod::StoreCredit")
    Spree::PaymentMethod.create(type: "Spree::PaymentMethod::StoreCredit", name: "Store Credit", description: "Store credit.", active: true, environment: Rails.env)
  end
end
