# The line item a bought gift card was issued for, so an order can list
# what it issued and a cancellation can find it.
class AddLineItemIdToSpreeGiftCards < ActiveRecord::Migration[8.1]
  def change
    add_reference :spree_gift_cards, :line_item, index: true
  end
end
