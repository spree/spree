class CreateSpreeStoreCredits < ActiveRecord::Migration
  def change
    create_table :spree_store_credits do |t|
      t.references :user
      t.references :category
      t.references :created_by
      t.decimal :amount, precision: 8, scale: 2, default: 0.0, null: false
      t.decimal :amount_used, precision: 8, scale: 2, default: 0.0, null: false
      t.text :memo
      t.datetime :deleted_at
      t.string :currency
      t.decimal :amount_authorized, precision: 8, scale: 2, default: 0.0, null: false
      t.integer :originator_id
      t.string :originator_type
      t.integer :type_id
      t.timestamps
    end

    add_index :spree_store_credits, :deleted_at
    add_index :spree_store_credits, :user_id
    add_index :spree_store_credits, :type_id
  end
end
