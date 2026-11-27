# How many of a line's received units can be resold, so one line can come back
# part resellable and part not. Lines received before this column existed keep
# their answer in `resellable` (see Spree::PostSale::ReceivedLine).
class AddResellableQuantityToPostSaleLineItems < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_return_line_items, :resellable_quantity, :integer, null: false, default: 0
    add_column :spree_exchange_line_items, :resellable_quantity, :integer, null: false, default: 0
  end
end
