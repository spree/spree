# A product whose variants are gift card denominations: buying one issues
# a card per unit when the order is paid.
class AddGiftCardToSpreeProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_products, :gift_card, :boolean, null: false, default: false
    add_index :spree_products, :gift_card
  end
end
