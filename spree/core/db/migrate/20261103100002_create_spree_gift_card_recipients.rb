# Who a gift card line is for. One row per gift card line item; lines
# without one send the code to the order's email.
class CreateSpreeGiftCardRecipients < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_gift_card_recipients do |t|
      t.references :store, null: false, index: false
      t.references :line_item, null: false, index: { unique: true }
      t.string :email, null: false
      t.string :name
      t.text :message
      t.datetime :send_at
      t.timestamps
    end

    add_index :spree_gift_card_recipients, [:store_id, :email]
  end
end
