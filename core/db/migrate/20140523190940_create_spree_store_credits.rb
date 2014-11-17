class CreateSpreeStoreCredits < ActiveRecord::Migration
  def change
    create_table :spree_store_credits do |t|
      t.references :user
      t.references :category
      t.references :created_by
      t.decimal :amount, precision: 8, scale: 2, null: false
      t.decimal :amount_used, precision: 8, scale: 2, default: 0.0, null: false
      t.text :memo
      t.timestamps
    end
  end
end
