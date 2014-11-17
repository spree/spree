class CreateSpreeStoreCreditEvents < ActiveRecord::Migration
  def change
    create_table :spree_store_credit_events do |t|
      t.integer :store_credit_id,    null: false
      t.string  :action,             null: false
      t.decimal :amount,             precision: 8,  scale: 2
      t.string  :authorization_code, null: false
    end

    add_index :spree_store_credit_events, :store_credit_id
  end
end
