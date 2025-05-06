class CreateSpreeGiftCardsAndSpreeGiftCardBatches < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_gift_card_batches, if_not_exists: true do |t|
      t.references :store, null: false
      t.integer :codes_count, default: 1, null: false
      t.decimal :amount, precision: 10, scale: 2, default: '10.0', null: false
      t.string :prefix
      t.date :expires_at
      t.decimal :minimum_order_amount, precision: 10, scale: 2, default: '0.0'

      t.timestamps
    end

    create_table :spree_gift_cards, if_not_exists: true do |t|
      t.references :store, null: false
      t.references :user
      t.references :store_credit
      t.date :expires_at
      t.string :code, null: false
      t.integer :state, default: 0, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :amount_remaining, precision: 10, scale: 2, default: '0.0', null: false
      t.references :gift_card_batch
      t.decimal :minimum_order_amount, precision: 10, scale: 2, default: '0.0'

      t.timestamps
    end

    add_index :spree_gift_cards, :code, unique: true

    add_column :spree_store_credits, :gift_card_id, :bigint, if_not_exists: true
    add_column :spree_store_credits, :expires_at, :datetime, if_not_exists: true
    add_column :spree_store_credits, :state, :integer, default: 0, if_not_exists: true
    add_index :spree_store_credits, :gift_card_id, if_not_exists: true

    add_column :spree_orders, :gift_card_id, :bigint, if_not_exists: true
    add_index :spree_orders, :gift_card_id, if_not_exists: true
  end
end
