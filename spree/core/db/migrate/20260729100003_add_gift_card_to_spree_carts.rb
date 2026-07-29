class AddGiftCardToSpreeCarts < ActiveRecord::Migration[7.2]
  def change
    add_reference :spree_carts, :gift_card, null: true
  end
end
