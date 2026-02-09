# This migration comes from spree (originally 20250506073057)
class CreateSpreeGiftCardsAndSpreeGiftCardBatches < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_gift_card_batches, if_not_exists: true do |t|
      t.references :store, null: false, index: true
      t.references :created_by
      t.integer :codes_count, default: 1, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, null: false
      t.string :prefix
      t.date :expires_at

      t.timestamps
    end

    create_table :spree_gift_cards, if_not_exists: true do |t|
      t.references :store, null: false, index: true
      t.references :user, index: true
      t.references :gift_card_batch, index: true
      t.references :created_by, index: true
      t.string :code, null: false
      t.string :state, null: false, index: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :amount_authorized, precision: 10, scale: 2, null: false, default: 0
      t.decimal :amount_used, precision: 10, scale: 2, null: false, default: 0
      t.string :currency, null: false

      t.date :expires_at, index: true
      t.datetime :redeemed_at, index: true
      t.timestamps
    end

    add_index :spree_gift_cards, :code, unique: { scope: :store_id }

    add_column :spree_orders, :gift_card_id, :bigint, if_not_exists: true
    add_index :spree_orders, :gift_card_id, if_not_exists: true
  end
end
